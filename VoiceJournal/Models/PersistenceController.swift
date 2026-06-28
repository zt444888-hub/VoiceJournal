 import CoreData
 
 /// Core Data stack with CloudKit sync.
 /// Configure App Groups + set `sharedContainerURL` in init for widget data sharing.
 struct PersistenceController {
     static let shared = PersistenceController()
     static let appGroupIdentifier = "group.com.yourname.VoiceJournal"  // 鈫?MUST set in Xcode
     
     let container: NSPersistentCloudKitContainer
     
         private static func createProgrammaticModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entryEntity = NSEntityDescription()
        entryEntity.name = "JournalEntry"
        entryEntity.managedObjectClassName = "JournalEntry"
        
        var properties: [NSPropertyDescription] = []
        
        let idProp = NSAttributeDescription()
        idProp.name = "id"
        idProp.attributeType = .UUIDAttributeType
        idProp.isOptional = true
        properties.append(idProp)
        
        let titleProp = NSAttributeDescription()
        titleProp.name = "title"
        titleProp.attributeType = .stringAttributeType
        titleProp.isOptional = true
        properties.append(titleProp)
        
        let transcriptProp = NSAttributeDescription()
        transcriptProp.name = "transcriptText"
        transcriptProp.attributeType = .stringAttributeType
        transcriptProp.isOptional = true
        properties.append(transcriptProp)
        
        let audioProp = NSAttributeDescription()
        audioProp.name = "audioFileName"
        audioProp.attributeType = .stringAttributeType
        audioProp.isOptional = true
        properties.append(audioProp)
        
        let sentimentProp = NSAttributeDescription()
        sentimentProp.name = "sentimentScore"
        sentimentProp.attributeType = .doubleAttributeType
        sentimentProp.isOptional = false
        sentimentProp.defaultValue = 0.0
        properties.append(sentimentProp)
        
        let durationProp = NSAttributeDescription()
        durationProp.name = "duration"
        durationProp.attributeType = .doubleAttributeType
        durationProp.isOptional = false
        durationProp.defaultValue = 0.0
        properties.append(durationProp)
        
        let createdAtProp = NSAttributeDescription()
        createdAtProp.name = "createdAt"
        createdAtProp.attributeType = .dateAttributeType
        createdAtProp.isOptional = true
        properties.append(createdAtProp)
        
        let updatedAtProp = NSAttributeDescription()
        updatedAtProp.name = "updatedAt"
        updatedAtProp.attributeType = .dateAttributeType
        updatedAtProp.isOptional = true
        properties.append(updatedAtProp)
        
        entryEntity.properties = properties
        model.entities = [entryEntity]
        return model
    }
init(inMemory: Bool = false, useProgrammaticModel: Bool = true) {
         container = NSPersistentCloudKitContainer(name: "VoiceJournal", managedObjectModel: Self.createProgrammaticModel())
         
         guard let description = container.persistentStoreDescriptions.first else {
             fatalError("No persistent store description")
         }
         
         if inMemory {
             description.url = URL(fileURLWithPath: "/dev/null")
         } else {
             // Use App Groups shared container so Widget can read the same data
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
         
         container.loadPersistentStores { _, error in
             if let error = error as NSError? {
                 print("鈿狅笍 CloudKit not available, falling back: \(error.localizedDescription)")
             }
         }
         
         container.viewContext.automaticallyMergesChangesFromParent = true
         container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
     }
     
     /// Saves only if there are uncommitted changes
     @discardableResult
     func save() -> Bool {
         let context = container.viewContext
         guard context.hasChanges else { return true }
         do {
             try context.save()
             return true
         } catch {
             print("鈿狅笍 Core Data save failed: \(error.localizedDescription)")
             return false
         }
     }
     
     /// Creates a separate read-only context (for use in Widget)
     func newReadOnlyContext() -> NSManagedObjectContext {
         let ctx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
         ctx.persistentStoreCoordinator = container.persistentStoreCoordinator
         ctx.automaticallyMergesChangesFromParent = true
         return ctx
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

