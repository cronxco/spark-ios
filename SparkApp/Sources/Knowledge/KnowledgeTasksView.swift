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
  @State private var showNewProject = false
  let projectsOnly: Bool

  private static let filters = ["today", "inbox", "all", "history", "deleted"]

  var body: some View {
    Group {
      if let model {
        ScrollView {
          VStack(spacing: SparkSpacing.lg) {
            if let error = model.error { StatusPill(.warning, message: error) }
            pendingSection(model: model)
            if projectsOnly {
              projectsContent(model: model)
            } else {
              tasksContent(model: model)
            }
          }
          .padding(.horizontal, SparkSpacing.lg)
          .padding(.top, SparkSpacing.md)
          .padding(.bottom, SparkSpacing.xl)
        }
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
        .sheet(isPresented: $showNewProject) {
          NavigationStack { KnowledgeProjectEditor(model: model, project: nil) }
        }
      } else {
        VStack(spacing: SparkSpacing.md) {
          ForEach(0..<3, id: \.self) { _ in LoadingShimmerCard().frame(height: 96) }
        }
        .padding(SparkSpacing.lg)
      }
    }
    .task(id: app.profile?.id) {
      model = nil
      editing = nil
      routedProject = nil
      showEditor = false
      showNewProject = false
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

  // MARK: Sections

  @ViewBuilder
  private func pendingSection(model: KnowledgeTasksViewModel) -> some View {
    if !model.pending.isEmpty {
      GlassCard(radius: SparkRadii.lg) {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
          Text("Waiting to sync")
            .font(SparkTypography.captionStrong)
            .foregroundStyle(.secondary)
          ForEach(model.pending) { change in
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: SparkSpacing.xxs) {
                Text(change.title).font(SparkTypography.bodyStrong)
                Text(change.error ?? "Saved on this device")
                  .font(SparkTypography.caption)
                  .foregroundStyle(change.error == nil ? Color.secondary : Color.sparkWarning)
              }
              Spacer(minLength: SparkSpacing.sm)
              Button("Discard", role: .destructive) { model.discard(change.id) }
                .font(SparkTypography.caption)
                .buttonStyle(.borderless)
            }
          }
        }
      }
    }
  }

  private func searchField(model: KnowledgeTasksViewModel, prompt: String) -> some View {
    @Bindable var model = model
    return HStack(spacing: SparkSpacing.sm) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField(prompt, text: $model.search)
        .font(SparkTypography.bodySmall)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      if !model.search.isEmpty {
        Button { model.search = "" } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear search")
      }
    }
    .padding(.horizontal, SparkSpacing.lg)
    .padding(.vertical, SparkSpacing.md)
    .sparkGlass(.capsule)
  }

  @ViewBuilder
  private func tasksContent(model: KnowledgeTasksViewModel) -> some View {
    let tasks = model.visible
    SparkSectionCaption(text: caption(count: tasks.count, noun: "task", filter: model.filter))
    searchField(model: model, prompt: "Search tasks")
    filterChips(model: model)
    HStack {
      PillButton("Add task", systemImage: "plus", tint: .domainKnowledge) {
        editing = nil
        showEditor = true
      }
      Spacer(minLength: SparkSpacing.md)
      if !tasks.isEmpty || selecting {
        Button(selecting ? "Done" : "Select") {
          selecting.toggle()
          selected = []
        }
        .font(SparkTypography.bodyStrong)
        .foregroundStyle(Color.domainKnowledge)
      }
    }
    if selecting { selectionBar(model: model) }
    if tasks.isEmpty {
      if model.loading {
        ForEach(0..<3, id: \.self) { _ in LoadingShimmerCard().frame(height: 96) }
      } else {
        EmptyState(
          systemImage: "checklist",
          title: model.search.isEmpty ? "No tasks here" : "No matching tasks",
          message: model.search.isEmpty ? "Tasks you add or that Spark finds will appear here." : nil
        )
      }
    } else {
      LazyVStack(spacing: SparkSpacing.md) {
        ForEach(tasks) { task in taskCard(task, model: model) }
      }
    }
  }

  @ViewBuilder
  private func projectsContent(model: KnowledgeTasksViewModel) -> some View {
    let projects = model.projects.filter {
      model.search.isEmpty || $0.title.localizedCaseInsensitiveContains(model.search)
        || ($0.content?.localizedCaseInsensitiveContains(model.search) ?? false)
    }
    SparkSectionCaption(text: caption(count: projects.count, noun: "project", filter: nil))
    searchField(model: model, prompt: "Search projects")
    HStack {
      PillButton("New project", systemImage: "plus", tint: .domainKnowledge) {
        showNewProject = true
      }
      Spacer(minLength: 0)
    }
    if projects.isEmpty {
      if model.loading {
        ForEach(0..<2, id: \.self) { _ in LoadingShimmerCard().frame(height: 120) }
      } else {
        EmptyState(
          systemImage: "folder",
          title: model.search.isEmpty ? "No projects yet" : "No matching projects",
          message: model.search.isEmpty ? "Group related tasks into a project." : nil
        )
      }
    } else {
      LazyVStack(spacing: SparkSpacing.md) {
        ForEach(projects) { project in projectCard(project, model: model) }
      }
    }
  }

  private func filterChips(model: KnowledgeTasksViewModel) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: SparkSpacing.sm) {
        ForEach(Self.filters, id: \.self) { filter in
          let isSelected = model.filter == filter
          Button { model.filter = filter } label: {
            Text(filterLabel(filter))
              .font(SparkTypography.bodyStrong)
              .foregroundStyle(isSelected ? Color.sparkOnAccent : Color.primary)
              .padding(.horizontal, SparkSpacing.lg)
              .frame(minHeight: 44)
              .background { if isSelected { Capsule().fill(Color.domainKnowledge) } }
              .sparkGlass(.capsule)
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  private func selectionBar(model: KnowledgeTasksViewModel) -> some View {
    GlassCard(radius: SparkRadii.lg) {
      HStack {
        Text("\(selected.count) selected").font(SparkTypography.bodyStrong)
        Spacer(minLength: SparkSpacing.sm)
        Menu("Actions") {
          Button("Complete", systemImage: "checkmark.circle") {
            applyToSelection(model) { await model.act($0, action: "complete") }
          }
          Button("Defer to tomorrow", systemImage: "calendar.badge.clock") {
            applyToSelection(model) { task in
              var calendar = Calendar(identifier: .gregorian)
              calendar.timeZone = TimeZone(identifier: task.scheduleTimezone) ?? .current
              let date = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
              await model.save(task: task, fields: ["availability_on": task.localDate(at: date)])
            }
          }
          Menu("Move to project") {
            ForEach(model.projects) { project in
              Button(project.title) {
                applyToSelection(model) {
                  await model.save(task: $0, fields: ["project_id": project.id])
                }
              }
            }
          }
          Button("Cancel tasks", systemImage: "xmark.circle", role: .destructive) {
            applyToSelection(model) { await model.act($0, action: "cancel") }
          }
        }
        .disabled(selected.isEmpty)
        .foregroundStyle(Color.domainKnowledge)
      }
    }
  }

  private func applyToSelection(
    _ model: KnowledgeTasksViewModel, _ work: @escaping (KnowledgeTask) async -> Void
  ) {
    Task {
      for task in model.visible where selected.contains(task.id) { await work(task) }
      selected = []
    }
  }

  // MARK: Cards

  private func taskCard(_ task: KnowledgeTask, model: KnowledgeTasksViewModel) -> some View {
    let date = task.localDate()
    let status = task.effectiveStatus(on: date)
    let isOpen = status == "open"
    return GlassCard(radius: SparkRadii.lg, padding: SparkSpacing.md) {
      HStack(alignment: .top, spacing: SparkSpacing.md) {
        leadingControl(task, status: status, model: model)
        Button {
          editing = task
          showEditor = true
        } label: {
          VStack(alignment: .leading, spacing: SparkSpacing.xs) {
            Text(task.title)
              .font(SparkTypography.bodyStrong)
              .strikethrough(status == "completed")
              .foregroundStyle(isOpen ? Color.primary : Color.secondary)
              .multilineTextAlignment(.leading)
            if let content = task.content, !content.isEmpty {
              Text(content)
                .font(SparkTypography.bodySmall)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            }
            taskMeta(task, status: status, date: date)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        taskMenu(task, status: status, model: model)
      }
    }
    .overlay(alignment: .leading) {
      if task.priority == "important" {
        Capsule().fill(Color.domainKnowledge).frame(width: 3).padding(.vertical, SparkSpacing.md)
      }
    }
  }

  @ViewBuilder
  private func leadingControl(
    _ task: KnowledgeTask, status: String, model: KnowledgeTasksViewModel
  ) -> some View {
    if selecting {
      Button {
        if selected.contains(task.id) { selected.remove(task.id) } else { selected.insert(task.id) }
      } label: {
        Image(systemName: selected.contains(task.id) ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundStyle(selected.contains(task.id) ? Color.domainKnowledge : .secondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(selected.contains(task.id) ? "Deselect \(task.title)" : "Select \(task.title)")
    } else if task.action == nil {
      Button {
        let primary = primaryAction(task, status: status)
        Task { await model.act(task, action: primary.action, date: primary.date) }
      } label: {
        Image(systemName: status == "completed" ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundStyle(status == "completed" ? Color.domainKnowledge : .secondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(primaryAction(task, status: status).label) \(task.title)")
    } else {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.title3)
        .foregroundStyle(Color.sparkWarning)
        .accessibilityHidden(true)
    }
  }

  private func primaryAction(_ task: KnowledgeTask, status: String) -> (
    action: String, date: String?, label: String
  ) {
    if status == "open" { return ("complete", nil, "Complete") }
    if status == "completed" { return ("reopen", nil, "Reopen") }
    if task.status == "deleted" { return ("restore", nil, "Restore") }
    return ("reactivate", task.localDate(), "Reactivate")
  }

  @ViewBuilder
  private func taskMeta(_ task: KnowledgeTask, status: String, date: String) -> some View {
    let overdue = status == "open" && (task.dueOn.map { $0 < date } ?? false)
    FlowChips {
      if let project = task.projectTitle { metaChip(project, systemImage: "folder", tint: .domainKnowledge) }
      if status != "open" || task.status == "deleted" {
        metaChip(task.status == "deleted" ? "Deleted" : status.capitalized, tint: .secondary)
      }
      if overdue {
        metaChip("Overdue", systemImage: "exclamationmark.circle", tint: .sparkWarning)
      } else if let due = task.dueOn {
        metaChip("Due \(due)", systemImage: "calendar", tint: .secondary)
      }
      if task.carriedDays > 0 {
        metaChip("Carried \(task.carriedDays)d", systemImage: "arrow.uturn.forward", tint: .secondary)
      }
      if task.recurrence != nil { metaChip("Repeats", systemImage: "repeat", tint: .secondary) }
      if task.sync.status != "synced" {
        metaChip("Outline \(task.sync.status)", systemImage: "arrow.triangle.2.circlepath", tint: .sparkWarning)
      }
    }
    if let action = task.action {
      NavigationLink {
        IntegrationDetailView(
          integrationId: action.integrationID, reauthOnOpen: action.kind == "integration_reauth")
      } label: {
        Label(
          action.kind == "integration_reauth" ? "Reconnect" : "Review connection",
          systemImage: "link"
        )
        .font(SparkTypography.captionStrong)
        .foregroundStyle(Color.domainKnowledge)
      }
    }
  }

  private func metaChip(_ text: String, systemImage: String? = nil, tint: Color) -> some View {
    HStack(spacing: SparkSpacing.xxs) {
      if let systemImage { Image(systemName: systemImage) }
      Text(text)
    }
    .font(SparkTypography.monoSmall)
    .foregroundStyle(tint)
    .padding(.horizontal, SparkSpacing.sm)
    .padding(.vertical, 3)
    .background(tint.opacity(0.14))
    .clipShape(.capsule)
  }

  private func taskMenu(
    _ task: KnowledgeTask, status: String, model: KnowledgeTasksViewModel
  ) -> some View {
    Menu {
      Button("Edit", systemImage: "pencil") {
        editing = task
        showEditor = true
      }
      if task.action == nil && status == "open" {
        Button("Cancel task", systemImage: "xmark.circle") {
          Task { await model.act(task, action: "cancel") }
        }
      }
      if let raw = task.sourceURL, task.sync.status != "synced", let url = URL(string: raw) {
        Link(destination: url) { Label("Open in Outline", systemImage: "arrow.up.right.square") }
      }
      if ["error", "blocked", "conflict"].contains(task.sync.status) {
        Button("Retry Outline sync", systemImage: "arrow.clockwise") {
          Task { await model.act(task, action: "retry_sync") }
        }
      }
      if task.status != "deleted" {
        Button("Delete task", systemImage: "trash", role: .destructive) {
          Task { await model.act(task, action: "delete") }
        }
      }
    } label: {
      Image(systemName: "ellipsis")
        .foregroundStyle(.secondary)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
    .accessibilityLabel("More actions for \(task.title)")
  }

  private func projectCard(_ project: KnowledgeProject, model: KnowledgeTasksViewModel) -> some View {
    Button {
      routedProject = project
    } label: {
      GlassCard(radius: SparkRadii.lg) {
        VStack(alignment: .leading, spacing: SparkSpacing.sm) {
          HStack(alignment: .firstTextBaseline) {
            Text(project.title).font(SparkTypography.bodyStrong).multilineTextAlignment(.leading)
            Spacer(minLength: SparkSpacing.sm)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
          }
          if let content = project.content, !content.isEmpty {
            Text(content)
              .font(SparkTypography.bodySmall)
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }
          if let progress = project.progress, progress.total > 0 {
            ProgressView(value: Double(progress.completed), total: Double(progress.total))
              .tint(Color.domainKnowledge)
            Text("\(progress.completed) of \(progress.total) completed")
              .font(SparkTypography.caption)
              .foregroundStyle(.secondary)
          }
          FlowChips {
            metaChip(
              project.status.capitalized,
              tint: project.status == "active" ? .domainKnowledge : .secondary)
            if let target = project.targetOn { metaChip("Target \(target)", systemImage: "flag", tint: .secondary) }
            if let next = model.tasks.first(where: { $0.id == project.nextActionTaskID }) {
              metaChip("Next: \(next.title)", systemImage: "arrow.right.circle", tint: .secondary)
            }
          }
        }
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: Helpers

  private func filterLabel(_ filter: String) -> String {
    switch filter {
    case "today": "Today"
    case "inbox": "Inbox"
    case "all": "All"
    case "history": "History"
    default: "Deleted"
    }
  }

  private func caption(count: Int, noun: String, filter: String?) -> String {
    let counted = "\(count) \(count == 1 ? noun : noun + "s")"
    guard let filter else { return counted }
    return "\(counted) in \(filterLabel(filter))"
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
}

/// Wraps chips onto as many lines as they need.
private struct FlowChips<Content: View>: View {
  @ViewBuilder let content: Content
  var body: some View {
    FlowLayout(spacing: SparkSpacing.xs) { content }
  }
}

private struct FlowLayout: Layout {
  var spacing: CGFloat
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(width: proposal.width ?? .infinity, subviews: subviews).size
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let result = arrange(width: bounds.width, subviews: subviews)
    for (index, origin) in result.origins.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
    }
  }
  private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
    var origins: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      origins.append(CGPoint(x: x, y: y))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      maxX = max(maxX, x - spacing)
    }
    return (CGSize(width: maxX, height: y + rowHeight), origins)
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
      if let error = model.error {
        Section { Text(error).foregroundStyle(Color.sparkWarning) }.glassRows()
      }
      Section {
        TextField("Task title", text: $title)
        TextField("Details", text: $content, axis: .vertical)
      }.glassRows()
      Section("Schedule") {
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
        if let task {
          Text("Dates use \(task.scheduleTimezone)")
            .font(SparkTypography.caption).foregroundStyle(.secondary)
        }
        if lifecycle == "week" {
          Text(
            "Expires seven calendar days after its original date. Deferring doesn't restart that window."
          ).font(SparkTypography.caption).foregroundStyle(.secondary)
        }
      }.glassRows()
      Section("Organise") {
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
        Stepper("Order: \(position)", value: $position, in: 0...10000)
      }.glassRows()
      if !model.topics.isEmpty {
        Section("Threads") {
          ForEach(model.topics) { topic in
            Toggle(
              topic.title,
              isOn: Binding(
                get: { threads.contains(topic.id) },
                set: { if $0 { threads.insert(topic.id) } else { threads.remove(topic.id) } }))
          }
        }.glassRows()
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
        }.glassRows()
      }
      if !activity.isEmpty {
        Section("Recent activity") {
          ForEach(activity) { change in
            VStack(alignment: .leading) {
              Text(change.action.replacingOccurrences(of: "_", with: " "))
              if let time = change.time {
                Text(time).font(SparkTypography.caption).foregroundStyle(.secondary)
              }
            }
          }
        }.glassRows()
      }
    }
    .editorSurface()
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
      if let error = model.error {
        Section { Text(error).foregroundStyle(Color.sparkWarning) }.glassRows()
      }
      Section {
        TextField("Project title", text: $title)
        TextField("Details", text: $content, axis: .vertical)
        TextField("Target YYYY-MM-DD", text: $target)
      }.glassRows()
      Section {
        Picker("Status", selection: $status) {
          ForEach(["active", "paused", "completed", "archived"], id: \.self) {
            Text($0.capitalized).tag($0)
          }
        }
        Toggle("Hide ordinary tasks when paused", isOn: $hideTasks)
        if status == "completed" || status == "archived" {
          Text("Unfinished tasks will remain active. Cancel or move them separately if needed.")
            .font(SparkTypography.caption).foregroundStyle(.secondary)
        }
        if let project {
          Picker("Next action", selection: $nextAction) {
            Text("None").tag("")
            ForEach(model.tasks.filter { $0.projectID == project.id && $0.status == "open" }) {
              Text($0.title).tag($0.id)
            }
          }
        }
      }.glassRows()
      if let project {
        Section {
          Button("Remove project", role: .destructive) {
            Task { if await model.removeProject(project) { dismiss() } }
          }
          Text("Tasks are kept without a project.")
            .font(SparkTypography.caption).foregroundStyle(.secondary)
        }.glassRows()
      }
    }.editorSurface()
      .navigationTitle(project == nil ? "New project" : "Edit project")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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
