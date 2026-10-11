import SparkKit
import SparkUI
import SwiftUI

struct KnowledgeTasksView: View {
  @Environment(AppModel.self) private var app
  @State private var model: KnowledgeTasksViewModel?
  @State private var editing: KnowledgeTask?
  @State private var showEditor = false
  @State private var selecting = false
  @State private var selected: Set<String> = []
  @State private var routedProject: KnowledgeProject?
  let projectsOnly: Bool
  var body: some View {
    Group {
      if let model {
        @Bindable var model = model
        List {
          if let error = model.error { Section { Text(error).foregroundStyle(.orange) } }
          if !model.pending.isEmpty {
            Section("Pending changes on this device") {
              ForEach(model.pending) { change in
                VStack(alignment: .leading) {
                  Text(change.title)
                  Text(change.error ?? "Waiting to sync").font(.caption)
                  Button("Discard pending change", role: .destructive) { model.discard(change.id) }
                }
              }
            }
          }
          if projectsOnly {
            Section {
              NavigationLink("New project") { KnowledgeProjectEditor(model: model, project: nil) }
            }
            ForEach(
              model.projects.filter {
                model.search.isEmpty || $0.title.localizedCaseInsensitiveContains(model.search)
                  || ($0.content?.localizedCaseInsensitiveContains(model.search) ?? false)
              }
            ) { project in
              Section {
                NavigationLink {
                  KnowledgeProjectEditor(model: model, project: project)
                } label: {
                  VStack(alignment: .leading) {
                    Text(project.title)
                    Text(project.status).font(.caption).foregroundStyle(.secondary)
                    if let progress = project.progress {
                      Text("\(progress.completed) / \(progress.total) completed").font(.caption)
                    }
                  }
                }
                ForEach(model.tasks.filter { $0.projectID == project.id }) { task in
                  taskRow(task, model: model)
                }
              }
            }
          } else {
            Section {
              Picker("View", selection: $model.filter) {
                Text("Today").tag("today")
                Text("Inbox").tag("inbox")
                Text("All").tag("all")
                Text("History").tag("history")
                Text("Deleted").tag("deleted")
              }.pickerStyle(.segmented)
              Button {
                editing = nil
                showEditor = true
              } label: {
                Label("Add task", systemImage: "plus")
              }
            }
            if selecting {
              Section("Selected tasks") {
                Button("Complete") {
                  Task {
                    for task in model.tasks where selected.contains(task.id) {
                      await model.act(task, action: "complete")
                    }
                    selected = []
                  }
                }
                Button("Defer to tomorrow") {
                  Task {
                    for task in model.tasks where selected.contains(task.id) {
                      var calendar = Calendar(identifier: .gregorian)
                      calendar.timeZone = TimeZone(identifier: task.scheduleTimezone) ?? .current
                      let date = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
                      await model.save(
                        task: task, fields: ["availability_on": task.localDate(at: date)])
                    }
                    selected = []
                  }
                }
                Button("Cancel", role: .destructive) {
                  Task {
                    for task in model.tasks where selected.contains(task.id) {
                      await model.act(task, action: "cancel")
                    }
                    selected = []
                  }
                }
                Menu("Move to project") {
                  ForEach(model.projects) { project in
                    Button(project.title) {
                      Task {
                        for task in model.tasks where selected.contains(task.id) {
                          await model.save(task: task, fields: ["project_id": project.id])
                        }
                        selected = []
                      }
                    }
                  }
                }
              }
            }
            ForEach(model.visible) { task in taskRow(task, model: model) }
          }
        }
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            if !projectsOnly {
              Button(selecting ? "Done" : "Select") {
                selecting.toggle()
                selected = []
              }
            }
          }
        }
        .searchable(text: $model.search, prompt: "Search tasks")
        .refreshable {
          let refreshed = await model.refresh()
          applyRoute(clearIfUnavailable: refreshed)
        }
        .onChange(of: model.loading) { _, loading in
          if !loading { applyRoute(clearIfUnavailable: model.lastRefreshSucceeded) }
        }
        .sheet(isPresented: $showEditor) {
          NavigationStack { KnowledgeTaskEditor(model: model, task: editing) }
        }
        .sheet(item: $routedProject) { project in
          NavigationStack { KnowledgeProjectEditor(model: model, project: project) }
        }
      } else {
        ProgressView()
      }
    }
    .task(id: app.profile?.id) {
      model = nil
      editing = nil
      routedProject = nil
      showEditor = false
      selected = []
      guard let account = app.profile?.id, !account.isEmpty else { return }
      let current = KnowledgeTasksViewModel(api: app.apiClient, accountID: account)
      model = current
      let refreshed = await current.refresh()
      guard app.profile?.id == account, model === current else { return }
      applyRoute(clearIfUnavailable: refreshed)
    }
    .onChange(of: app.pendingRoute) { _, route in
      applyRoute()
      guard let model else { return }
      switch route {
      case .knowledgeTask, .knowledgeProject:
        Task {
          let refreshed = await model.refresh()
          guard self.model === model else { return }
          applyRoute(clearIfUnavailable: refreshed)
        }
      default: break
      }
    }
  }
  private func applyRoute(clearIfUnavailable: Bool = false) {
    guard let model else { return }
    switch app.pendingRoute {
    case .knowledgeTask(let id) where !projectsOnly:
      guard let task = model.tasks.first(where: { $0.id == id }) else {
        if clearIfUnavailable && !model.loading { app.pendingRoute = nil }
        return
      }
      editing = task
      showEditor = true
      app.pendingRoute = nil
    case .knowledgeProject(let id) where projectsOnly:
      guard let project = model.projects.first(where: { $0.id == id }) else {
        if clearIfUnavailable && !model.loading { app.pendingRoute = nil }
        return
      }
      routedProject = project
      app.pendingRoute = nil
    default: break
    }
  }
  private func taskRow(_ task: KnowledgeTask, model: KnowledgeTasksViewModel) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      if selecting {
        Toggle(
          "Select task",
          isOn: Binding(
            get: { selected.contains(task.id) },
            set: { if $0 { selected.insert(task.id) } else { selected.remove(task.id) } }))
      }
      Button {
        editing = task
        showEditor = true
      } label: {
        VStack(alignment: .leading) {
          Text(task.title).font(.headline)
          Text(
            [task.effectiveStatus(on: task.localDate()), task.lifecycle, task.projectTitle]
              .compactMap { $0 }.joined(separator: " · ")
          ).font(.caption)
        }
      }.buttonStyle(.plain)
      if let content = task.content, !content.isEmpty { Text(content).font(.subheadline) }
      if task.effectiveStatus(on: task.localDate()) == "open", let due = task.dueOn,
        due < task.localDate()
      {
        Text("Overdue").foregroundStyle(.orange)
      }
      if task.carriedDays > 0 { Text("Carried \(task.carriedDays) days").font(.caption) }
      if task.sync.status != "synced" {
        Text("Outline: \(task.sync.status)").foregroundStyle(.orange)
        if let raw = task.sourceURL, let url = URL(string: raw) {
          Link("Open in Outline", destination: url)
        }
      }
      if let action = task.action {
        NavigationLink(action.kind == "integration_reauth" ? "Reconnect" : "Review connection") {
          IntegrationDetailView(
            integrationId: action.integrationID, reauthOnOpen: action.kind == "integration_reauth")
        }
      } else {
        HStack {
          if task.effectiveStatus(on: task.localDate()) == "open" {
            Button("Complete") { Task { await model.act(task, action: "complete") } }
          } else if task.status == "completed" {
            Button("Reopen") { Task { await model.act(task, action: "reopen") } }
          } else if task.status == "deleted" {
            Button("Restore") { Task { await model.act(task, action: "restore") } }
          } else {
            Button("Reactivate today") {
              Task { await model.act(task, action: "reactivate", date: task.localDate()) }
            }
          }
          Button("Cancel", role: .destructive) { Task { await model.act(task, action: "cancel") } }
        }.buttonStyle(.borderless)
      }
    }.padding(.vertical, 4)
      .contextMenu {
        if task.status != "deleted" {
          Button("Delete task", role: .destructive) {
            Task { await model.act(task, action: "delete") }
          }
        }
        if task.sync.status == "error" || task.sync.status == "blocked"
          || task.sync.status == "conflict"
        {
          Button("Retry Outline sync") { Task { await model.act(task, action: "retry_sync") } }
        }
      }
  }
}

private struct KnowledgeTaskEditor: View {
  let model: KnowledgeTasksViewModel
  let task: KnowledgeTask?
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var content = ""
  @State private var lifecycle = "persistent"
  @State private var availability = ""
  @State private var due = ""
  @State private var project = ""
  @State private var threads: Set<String> = []
  @State private var important = false
  @State private var recurrence = ""
  @State private var review = ""
  @State private var hasReminder = false
  @State private var reminderDate = Date.now
  @State private var position = 0
  @State private var activity: [KnowledgeTaskHistory] = []
  var body: some View {
    Form {
      if let error = model.error { Text(error).foregroundStyle(.orange) }
      TextField("Task title", text: $title)
      TextField("Details", text: $content, axis: .vertical)
      Picker("Duration", selection: $lifecycle) {
        Text("Single day").tag("day")
        Text("Up to seven days").tag("week")
        Text("Until completed").tag("persistent")
      }
      Toggle("Schedule this task", isOn: hasDate($availability))
      if !availability.isEmpty {
        DatePicker("Available", selection: dateBinding($availability), displayedComponents: .date)
      }
      Toggle("Set a deadline", isOn: hasDate($due))
      if !due.isEmpty {
        DatePicker("Due", selection: dateBinding($due), displayedComponents: .date)
      }
      Toggle("Set a review date", isOn: hasDate($review))
      if !review.isEmpty {
        DatePicker("Review", selection: dateBinding($review), displayedComponents: .date)
      }
      Toggle("Remind me", isOn: $hasReminder)
      if hasReminder { DatePicker("Reminder", selection: $reminderDate) }
      Stepper("Order: \(position)", value: $position, in: 0...10000)
      if let task { Text("Dates use \(task.scheduleTimezone)").font(.caption) }
      Picker("Project", selection: $project) {
        Text("None").tag("")
        ForEach(model.projects) { Text($0.title).tag($0.id) }
      }
      Toggle("Important", isOn: $important)
      Picker("Repeat", selection: $recurrence) {
        Text("Never").tag("")
        Text("Daily").tag("daily")
        Text("Weekly").tag("weekly")
        Text("Monthly").tag("monthly")
      }
      Section("Threads") {
        ForEach(model.topics) { topic in
          Toggle(
            topic.title,
            isOn: Binding(
              get: { threads.contains(topic.id) },
              set: { if $0 { threads.insert(topic.id) } else { threads.remove(topic.id) } }))
        }
      }
      if let task, let context = task.context, !context.isEmpty {
        Section("Related items") {
          ForEach(context, id: \.id) { item in
            Button(item.title ?? "Open related item") {
              if let route = AppModel.route(from: "\(item.kind):\(item.id)") {
                dismiss()
                AppModel.shared.pendingRoute = route
              }
            }
          }
        }
      }
      if !activity.isEmpty {
        Section("Recent activity") {
          ForEach(activity) { change in
            VStack(alignment: .leading) {
              Text(change.action.replacingOccurrences(of: "_", with: " "))
              if let time = change.time { Text(time).font(.caption) }
            }
          }
        }
      }
      if lifecycle == "week" {
        Text(
          "Expires seven calendar days after its original date. Deferring doesn't restart that window."
        ).font(.caption)
      }
    }
    .environment(
      \.timeZone, TimeZone(identifier: task?.scheduleTimezone ?? model.timezone) ?? .current
    )
    .navigationTitle(task == nil ? "Add task" : "Edit task")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          Task {
            let saved = await model.save(
              task: task,
              fields: [
                "title": title, "content": content, "lifecycle": lifecycle,
                "availability_on": availability.isEmpty ? NSNull() : availability as Any,
                "due_on": due.isEmpty ? NSNull() : due as Any,
                "project_id": project.isEmpty ? NSNull() : project as Any,
                "thread_ids": Array(threads).sorted(),
                "priority": important ? "important" : "normal",
                "recurrence": recurrence.isEmpty ? NSNull() : recurrence as Any,
                "position": position, "review_on": review.isEmpty ? NSNull() : review as Any,
                "remind_at": hasReminder
                  ? ISO8601DateFormatter().string(from: reminderDate) as Any : NSNull(),
              ])
            if saved { dismiss() }
          }
        }.disabled(
          title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (lifecycle != "persistent" && availability.isEmpty))
      }
    }
    .task { if let task { activity = await model.history(task) } }
    .onAppear {
      title = task?.title ?? ""
      content = task?.content ?? ""
      lifecycle = task?.lifecycle ?? "persistent"
      availability = task?.availabilityOn ?? ""
      due = task?.dueOn ?? ""
      project = task?.projectID ?? ""
      threads = Set(task?.threadIDs ?? [])
      important = task?.priority == "important"
      recurrence = task?.recurrence ?? ""
      position = task?.position ?? 0
      review = task?.reviewOn ?? ""
      hasReminder = task?.remindAt != nil
      reminderDate = task?.remindAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .now
    }
  }
  private func formatter() -> DateFormatter {
    let format = DateFormatter()
    format.calendar = Calendar(identifier: .gregorian)
    format.locale = Locale(identifier: "en_US_POSIX")
    format.timeZone = TimeZone(identifier: task?.scheduleTimezone ?? model.timezone) ?? .current
    format.dateFormat = "yyyy-MM-dd"
    return format
  }
  private func hasDate(_ value: Binding<String>) -> Binding<Bool> {
    Binding(
      get: { !value.wrappedValue.isEmpty },
      set: { value.wrappedValue = $0 ? formatter().string(from: .now) : "" })
  }
  private func dateBinding(_ value: Binding<String>) -> Binding<Date> {
    Binding(
      get: { formatter().date(from: value.wrappedValue) ?? .now },
      set: { value.wrappedValue = formatter().string(from: $0) })
  }

}
private struct KnowledgeProjectEditor: View {
  let model: KnowledgeTasksViewModel
  let project: KnowledgeProject?
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var content = ""
  @State private var status = "active"
  @State private var target = ""
  @State private var nextAction = ""
  @State private var hideTasks = true
  var body: some View {
    Form {
      if let error = model.error { Text(error).foregroundStyle(.orange) }
      TextField("Project title", text: $title)
      TextField("Details", text: $content, axis: .vertical)
      TextField("Target YYYY-MM-DD", text: $target)
      Picker("Status", selection: $status) {
        ForEach(["active", "paused", "completed", "archived"], id: \.self) {
          Text($0.capitalized).tag($0)
        }
      }
      Toggle("Hide ordinary tasks when paused", isOn: $hideTasks)
      if status == "completed" || status == "archived" {
        Text("Unfinished tasks will remain active. Cancel or move them separately if needed.").font(
          .caption)
      }
      if let project {
        Picker("Next action", selection: $nextAction) {
          Text("None").tag("")
          ForEach(model.tasks.filter { $0.projectID == project.id && $0.status == "open" }) {
            Text($0.title).tag($0.id)
          }
        }
      }
      if let project {
        Section {
          Button("Remove project", role: .destructive) {
            Task { if await model.removeProject(project) { dismiss() } }
          }
          Text("Tasks are kept without a project.").font(.caption)
        }
      }
    }.navigationTitle(project == nil ? "New project" : "Edit project")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            Task {
              await model.saveProject(
                project,
                fields: [
                  "title": title, "content": content, "status": status,
                  "target_on": target.isEmpty ? NSNull() : target as Any,
                  "hide_tasks": hideTasks,
                  "next_action_task_id": nextAction.isEmpty ? NSNull() : nextAction as Any,
                ])
              if model.error == nil { dismiss() }
            }
          }.disabled(title.isEmpty)
        }
      }
      .onAppear {
        title = project?.title ?? ""
        content = project?.content ?? ""
        status = project?.status ?? "active"
        target = project?.targetOn ?? ""
        nextAction = project?.nextActionTaskID ?? ""
        hideTasks = project?.hideTasks ?? true
      }
  }
}
