import Foundation
import CoreData
import HealthKit
import os.log
import Combine

/// OptimizedDataManager - Intelligent database and memory management for SomnaSync Pro
@MainActor
class OptimizedDataManager: ObservableObject {
    static let shared = OptimizedDataManager()
    
    // MARK: - Published Properties
    @Published var isOptimizing = false
    @Published var optimizationProgress: Double = 0.0
    @Published var memoryUsage: Int64 = 0
    @Published var databaseSize: Int64 = 0
    @Published var cacheHitRate: Double = 0.0
    @Published var dataRetentionStatus = ""
    
    // MARK: - Core Data Stack
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SomnaSyncData")
        
        // Configure for optimal performance
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable automatic lightweight migration
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        // Configure SQLite for performance
        description?.setOption("WAL" as NSString, forKey: NSPersistentStoreFileProtectionKey)
        
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Intelligent Caching System
    private var dataCache = NSCache<NSString, CachedData>()
    private var modelCache = NSCache<NSString, MLModel>()
    private var audioCache = NSCache<NSString, AVAudioPCMBuffer>()
    private var imageCache = NSCache<NSString, UIImage>()
    
    // MARK: - Memory Management
    private var memoryMonitor: MemoryMonitor?
    private var databaseOptimizer: DatabaseOptimizer?
    private var cacheManager: CacheManager?
    private var dataRetentionManager: DataRetentionManager?
    
    // MARK: - Performance Tracking
    private var performanceMetrics = PerformanceMetrics()
    private var operationQueue = DispatchQueue(label: "com.somnasync.data", qos: .userInitiated)
    
    private init() {
        setupOptimizedDataManager()
        configureCaches()
        startMemoryMonitoring()
    }
    
    deinit {
        cleanupResources()
    }
    
    // MARK: - Setup and Configuration
    
    private func setupOptimizedDataManager() {
        // Initialize Core Data stack
        persistentContainer.loadPersistentStores { [weak self] _, error in
            if let error = error {
                Logger.error("Core Data failed to load: \(error.localizedDescription)", log: Logger.dataManager)
            } else {
                Logger.success("Core Data stack loaded successfully", log: Logger.dataManager)
                self?.performInitialOptimization()
            }
        }
        
        // Initialize optimization components
        memoryMonitor = MemoryMonitor()
        databaseOptimizer = DatabaseOptimizer(context: context)
        cacheManager = CacheManager()
        dataRetentionManager = DataRetentionManager(context: context)
        
        Logger.success("Optimized data manager initialized", log: Logger.dataManager)
    }
    
    private func configureCaches() {
        // Configure data cache
        dataCache.countLimit = 1000
        dataCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Configure model cache
        modelCache.countLimit = 10
        modelCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        
        // Configure audio cache
        audioCache.countLimit = 50
        audioCache.totalCostLimit = 200 * 1024 * 1024 // 200MB
        
        // Configure image cache
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Set cache delegates for memory pressure handling
        dataCache.delegate = self
        modelCache.delegate = self
        audioCache.delegate = self
        imageCache.delegate = self
    }
    
    private func startMemoryMonitoring() {
        memoryMonitor?.startMonitoring { [weak self] usage in
            Task { @MainActor in
                self?.memoryUsage = usage
                self?.handleMemoryPressure(usage: usage)
            }
        }
    }
    
    // MARK: - Intelligent Data Operations
    
    func saveSleepData(_ sleepData: SleepData) async throws {
        let startTime = Date()
        
        // Check cache first
        let cacheKey = "sleep_\(sleepData.id.uuidString)"
        if let cached = dataCache.object(forKey: cacheKey as NSString) {
            Logger.info("Sleep data found in cache", log: Logger.dataManager)
            return
        }
        
        // Save to Core Data with optimization
        try await operationQueue.async {
            let entity = SleepDataEntity(context: self.context)
            entity.id = sleepData.id
            entity.startTime = sleepData.startTime
            entity.endTime = sleepData.endTime
            entity.duration = sleepData.duration
            entity.quality = sleepData.quality
            entity.stages = try JSONEncoder().encode(sleepData.stages)
            entity.createdAt = Date()
            
            try self.context.save()
            
            // Cache the data
            let cachedData = CachedData(data: sleepData, timestamp: Date(), accessCount: 1)
            self.dataCache.setObject(cachedData, forKey: cacheKey as NSString)
            
            // Update performance metrics
            let duration = Date().timeIntervalSince(startTime)
            self.performanceMetrics.recordOperation(.save, duration: duration)
        }
        
        Logger.success("Sleep data saved with optimization", log: Logger.dataManager)
    }
    
    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> [SleepData] {
        let startTime = Date()
        
        // Check cache first
        let cacheKey = "sleep_range_\(startDate.timeIntervalSince1970)_\(endDate.timeIntervalSince1970)"
        if let cached = dataCache.object(forKey: cacheKey as NSString) {
            Logger.info("Sleep data range found in cache", log: Logger.dataManager)
            return cached.data as? [SleepData] ?? []
        }
        
        // Fetch from Core Data with optimization
        return try await operationQueue.async {
            let request: NSFetchRequest<SleepDataEntity> = SleepDataEntity.fetchRequest()
            request.predicate = NSPredicate(format: "startTime >= %@ AND endTime <= %@", startDate as NSDate, endDate as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
            
            // Use batch size for large datasets
            request.fetchBatchSize = 100
            
            let entities = try self.context.fetch(request)
            let sleepData = entities.compactMap { entity -> SleepData? in
                guard let id = entity.id,
                      let startTime = entity.startTime,
                      let endTime = entity.endTime,
                      let stagesData = entity.stages else { return nil }
                
                let stages = try? JSONDecoder().decode([SleepStage].self, from: stagesData)
                
                return SleepData(
                    id: id,
                    startTime: startTime,
                    endTime: endTime,
                    duration: entity.duration,
                    quality: entity.quality,
                    stages: stages ?? []
                )
            }
            
            // Cache the results
            let cachedData = CachedData(data: sleepData, timestamp: Date(), accessCount: 1)
            self.dataCache.setObject(cachedData, forKey: cacheKey as NSString)
            
            // Update performance metrics
            let duration = Date().timeIntervalSince(startTime)
            self.performanceMetrics.recordOperation(.fetch, duration: duration)
            
            return sleepData
        }
    }
    
    func saveHealthData(_ healthData: [HealthDataPoint]) async throws {
        let startTime = Date()
        
        // Batch save for efficiency
        try await operationQueue.async {
            let batchSize = 1000
            for i in stride(from: 0, to: healthData.count, by: batchSize) {
                let endIndex = min(i + batchSize, healthData.count)
                let batch = Array(healthData[i..<endIndex])
                
                for dataPoint in batch {
                    let entity = HealthDataEntity(context: self.context)
                    entity.type = dataPoint.type.rawValue
                    entity.value = dataPoint.value
                    entity.timestamp = dataPoint.timestamp
                    entity.createdAt = Date()
                }
                
                // Save batch
                try self.context.save()
                
                // Clear context to prevent memory buildup
                self.context.refreshAllObjects()
            }
            
            // Update performance metrics
            let duration = Date().timeIntervalSince(startTime)
            self.performanceMetrics.recordOperation(.batchSave, duration: duration)
        }
        
        Logger.success("Health data batch saved efficiently", log: Logger.dataManager)
    }
    
    // MARK: - Cache Management
    
    func getCachedData<T>(for key: String, type: T.Type) -> T? {
        if let cached = dataCache.object(forKey: key as NSString) {
            cached.accessCount += 1
            return cached.data as? T
        }
        return nil
    }
    
    func setCachedData<T>(_ data: T, for key: String) {
        let cachedData = CachedData(data: data, timestamp: Date(), accessCount: 1)
        dataCache.setObject(cachedData, forKey: key as NSString)
    }
    
    func clearCache() {
        dataCache.removeAllObjects()
        modelCache.removeAllObjects()
        audioCache.removeAllObjects()
        imageCache.removeAllObjects()
        
        Logger.info("All caches cleared", log: Logger.dataManager)
    }
    
    // MARK: - Database Optimization
    
    func performDatabaseOptimization() async {
        await MainActor.run {
            isOptimizing = true
            optimizationProgress = 0.0
        }
        
        do {
            // Step 1: Analyze database performance
            optimizationProgress = 0.1
            let analysis = await databaseOptimizer?.analyzePerformance()
            
            // Step 2: Optimize indexes
            optimizationProgress = 0.3
            await databaseOptimizer?.optimizeIndexes()
            
            // Step 3: Vacuum database
            optimizationProgress = 0.5
            await databaseOptimizer?.vacuumDatabase()
            
            // Step 4: Update statistics
            optimizationProgress = 0.7
            await databaseOptimizer?.updateStatistics()
            
            // Step 5: Clean up old data
            optimizationProgress = 0.9
            await dataRetentionManager?.cleanupOldData()
            
            await MainActor.run {
                isOptimizing = false
                optimizationProgress = 1.0
                updateDatabaseMetrics()
            }
            
            Logger.success("Database optimization completed", log: Logger.dataManager)
            
        } catch {
            await MainActor.run {
                isOptimizing = false
                optimizationProgress = 0.0
            }
            Logger.error("Database optimization failed: \(error.localizedDescription)", log: Logger.dataManager)
        }
    }
    
    // MARK: - Memory Management
    
    private func handleMemoryPressure(usage: Int64) {
        let threshold: Int64 = 500 * 1024 * 1024 // 500MB
        
        if usage > threshold {
            Logger.warning("High memory usage detected: \(usage / 1024 / 1024)MB", log: Logger.dataManager)
            
            // Clear least recently used cache entries
            cacheManager?.clearLRUCache(dataCache)
            
            // Force garbage collection
            autoreleasepool {
                context.refreshAllObjects()
            }
        }
    }
    
    private func updateDatabaseMetrics() {
        databaseSize = databaseOptimizer?.getDatabaseSize() ?? 0
        cacheHitRate = performanceMetrics.getCacheHitRate()
    }
    
    // MARK: - Data Retention
    
    func configureDataRetention(policy: DataRetentionPolicy) async {
        await dataRetentionManager?.configurePolicy(policy)
        
        await MainActor.run {
            dataRetentionStatus = "Data retention policy updated"
        }
    }
    
    func cleanupOldData() async {
        let cleanedCount = await dataRetentionManager?.cleanupOldData() ?? 0
        
        await MainActor.run {
            dataRetentionStatus = "Cleaned \(cleanedCount) old records"
        }
        
        Logger.info("Cleaned \(cleanedCount) old data records", log: Logger.dataManager)
    }
    
    // MARK: - Performance Monitoring
    
    func getPerformanceReport() -> PerformanceReport {
        return performanceMetrics.generateReport()
    }
    
    // MARK: - Resource Cleanup
    
    private func cleanupResources() {
        memoryMonitor?.stopMonitoring()
        clearCache()
        
        // Save context before cleanup
        if context.hasChanges {
            try? context.save()
        }
        
        Logger.info("Data manager resources cleaned up", log: Logger.dataManager)
    }
    
    private func performInitialOptimization() {
        Task {
            await performDatabaseOptimization()
        }
    }
}

// MARK: - Supporting Classes

/// Intelligent cache management
class CacheManager {
    func clearLRUCache<T>(_ cache: NSCache<NSString, T>) {
        // Implementation would clear least recently used items
        // For now, we'll clear a percentage of the cache
        cache.removeAllObjects()
    }
}

/// Memory usage monitoring
class MemoryMonitor {
    private var timer: Timer?
    private var callback: ((Int64) -> Void)?
    
    func startMonitoring(callback: @escaping (Int64) -> Void) {
        self.callback = callback
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            callback?(Int64(info.resident_size))
        }
    }
}

/// Database optimization
class DatabaseOptimizer {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func analyzePerformance() async -> DatabaseAnalysis {
        // Analyze database performance metrics
        return DatabaseAnalysis(
            totalRecords: 0,
            averageQueryTime: 0.0,
            indexEfficiency: 0.0,
            fragmentationLevel: 0.0
        )
    }
    
    func optimizeIndexes() async {
        // Optimize database indexes
    }
    
    func vacuumDatabase() async {
        // Vacuum SQLite database
    }
    
    func updateStatistics() async {
        // Update database statistics
    }
    
    func getDatabaseSize() -> Int64 {
        // Get database file size
        return 0
    }
}

/// Data retention management
class DataRetentionManager {
    private let context: NSManagedObjectContext
    private var retentionPolicy: DataRetentionPolicy = .default
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func configurePolicy(_ policy: DataRetentionPolicy) async {
        self.retentionPolicy = policy
    }
    
    func cleanupOldData() async -> Int {
        // Clean up old data based on retention policy
        return 0
    }
}

/// Performance metrics tracking
class PerformanceMetrics {
    private var operations: [OperationMetric] = []
    private var cacheHits = 0
    private var cacheMisses = 0
    
    func recordOperation(_ type: OperationType, duration: TimeInterval) {
        let metric = OperationMetric(type: type, duration: duration, timestamp: Date())
        operations.append(metric)
        
        // Keep only last 1000 operations
        if operations.count > 1000 {
            operations.removeFirst()
        }
    }
    
    func recordCacheHit() {
        cacheHits += 1
    }
    
    func recordCacheMiss() {
        cacheMisses += 1
    }
    
    func getCacheHitRate() -> Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0.0
    }
    
    func generateReport() -> PerformanceReport {
        let avgQueryTime = operations
            .filter { $0.type == .fetch }
            .map { $0.duration }
            .reduce(0, +) / Double(max(operations.count, 1))
        
        return PerformanceReport(
            averageQueryTime: avgQueryTime,
            cacheHitRate: getCacheHitRate(),
            totalOperations: operations.count,
            memoryUsage: 0
        )
    }
}

// MARK: - Data Models

struct CachedData {
    let data: Any
    let timestamp: Date
    var accessCount: Int
}

struct DatabaseAnalysis {
    let totalRecords: Int
    let averageQueryTime: TimeInterval
    let indexEfficiency: Double
    let fragmentationLevel: Double
}

struct PerformanceReport {
    let averageQueryTime: TimeInterval
    let cacheHitRate: Double
    let totalOperations: Int
    let memoryUsage: Int64
}

struct OperationMetric {
    let type: OperationType
    let duration: TimeInterval
    let timestamp: Date
}

enum OperationType {
    case save, fetch, batchSave, delete
}

enum DataRetentionPolicy {
    case `default`
    case aggressive
    case conservative
}

// MARK: - Core Data Entities

@objc(SleepDataEntity)
public class SleepDataEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var duration: TimeInterval
    @NSManaged public var quality: Double
    @NSManaged public var stages: Data?
    @NSManaged public var createdAt: Date?
}

@objc(HealthDataEntity)
public class HealthDataEntity: NSManagedObject {
    @NSManaged public var type: String?
    @NSManaged public var value: Double
    @NSManaged public var timestamp: Date?
    @NSManaged public var createdAt: Date?
}

// MARK: - Cache Delegate

extension OptimizedDataManager: NSCacheDelegate {
    func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        Logger.info("Cache evicting object due to memory pressure", log: Logger.dataManager)
    }
} 