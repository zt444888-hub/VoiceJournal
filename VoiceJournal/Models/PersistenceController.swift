 import CoreData
 import Combine
 
 /// Core Data stack with CloudKit sync.
 /// Exposes `cloudKitAvailable` for UI to show sync status.
 struct PersistenceController {
     static let shared = PersistenceController()
     static let appGroupIdentifier = "group.com.yourname.VoiceJournal"
     
     let container: NSPersistentCloudKitContainer
     let cloudKitAvailable: CurrentValueSubject<Bool, Never>
     
     init(inMemory: Bool = false) {
         container = NSPersistentCloudKitContainer(name: "VoiceJournal")
         cloudKitAvailable = CurrentValueSubject(false)
         
         guard let description = container.persistentStoreDescriptions.first else {
             fatalError("No persistent store description")
         }
         
         if inMemory {
             description.url = URL(fileURLWithPath: "/dev/null")
         } else {
             if let groupURL = FileManager.default
                 .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
                 let storeURL = groupURL.appendingPathComponent("VoiceJournal.sqlite")
                 description.url = storeURL
             }
         }
         
         description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
         description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
             containerIdentifier: "iCloud.com.yourname.VoiceJournal"
         )
         
         container.loadPersistentStores { [self] _, error in
             cloudKitAvailable.value = error == nil
             if let error = error {
                 print("⚠️ CloudKit fallback to local: \(error.localizedDescription)")
             }
         }
         
         container.viewContext.automaticallyMergesChangesFromParent = true
         container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
     }
     
     @discardableResult
     func save() -> Bool {
         let context = container.viewContext
         guard context.hasChanges else { return true }
         do {
             try context.save()
             return true
         } catch {
             print("⚠️ Core Data save failed: \(error.localizedDescription)")
             return false
         }
     }
     
     /// Read-only context for Widget
     func newReadOnlyContext() -> NSManagedObjectContext {
         let ctx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
         ctx.persistentStoreCoordinator = container.persistentStoreCoordinator
         ctx.automaticallyMergesChangesFromParent = true
         ctx.mergePolicy = NSRollbackMergePolicy
         return ctx
     }
     
     static func isCloudKitAvailable() -> Bool {
         shared.cloudKitAvailable.value
     }
 }
 
 // MARK: - Preview
 extension PersistenceController {
     static var preview: PersistenceController = {
         let controller = PersistenceController(inMemory: true)
         let viewContext = controller.container.viewContext
         for i in 0..<5 {
             let entry = JournalEntry(context: viewContext)
             entry.id = UUID()
             entry.title = "Day \(i + 1) Reflection"
             entry.transcriptText = "Today was a productive day. I finished the project and felt great."
             entry.sentimentScore = Double.random(in: -0.3...0.8)
             entry.createdAt = Date().addingTimeInterval(-Double(i) * 86400)
             entry.duration = Double.random(in: 30...180)
         }
         try? viewContext.save()
         return controller
     }()
 }
