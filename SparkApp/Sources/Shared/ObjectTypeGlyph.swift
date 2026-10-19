import SparkKit

/// SF Symbol for an object's type, shared by search results and the detail
/// screens. Every object used to share one cube, so a track, a bookmark and a
/// day note were indistinguishable in a list. Unknown types keep a box.
enum ObjectTypeGlyph {
    static func symbol(type: String?, concept: String? = nil) -> String {
        switch type?.lowercased() {
        case "track", "album", "song": return "music.note"
        case "playlist": return "music.note.list"
        case "podcast", "episode", "podcast_episode": return "mic.fill"
        case "bookmark": return "bookmark.fill"
        case "article", "newsletter", "publication", "newsletter_publication", "newsletter_post": return "newspaper.fill"
        case "day_note", "note", "document": return "note.text"
        case "person", "contact": return "person.fill"
        case "book": return "book.fill"
        case "movie", "film", "show", "tv_show", "tv_episode": return "film"
        default: break
        }

        switch concept?.lowercased() {
        case "person": return "person.fill"
        case "user": return "person.crop.circle"
        case "place": return "mappin.circle.fill"
        case "publication": return "newspaper.fill"
        case "media": return "play.rectangle.fill"
        default: return "shippingbox"
        }
    }
}
