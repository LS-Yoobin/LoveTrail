import Foundation

enum VoiceMemoStorage {
    case prelude
    case letter

    func save(data: Data, fileId: String) {
        switch self {
        case .prelude:
            DataPersistenceManager.shared.savePreludeVoiceMemo(data: data, fileId: fileId)
        case .letter:
            DataPersistenceManager.shared.saveLetterVoiceMemo(data: data, fileId: fileId)
        }
    }

    func load(fileId: String) -> Data? {
        switch self {
        case .prelude:
            return DataPersistenceManager.shared.loadPreludeVoiceMemoData(fileId: fileId)
        case .letter:
            return DataPersistenceManager.shared.loadLetterVoiceMemoData(fileId: fileId)
        }
    }

    func delete(fileId: String) {
        switch self {
        case .prelude:
            DataPersistenceManager.shared.deletePreludeVoiceMemo(fileId: fileId)
        case .letter:
            DataPersistenceManager.shared.deleteLetterVoiceMemo(fileId: fileId)
        }
    }
}
