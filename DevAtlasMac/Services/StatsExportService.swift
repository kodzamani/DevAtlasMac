import Foundation
import AppKit
import UniformTypeIdentifiers

class StatsExportService {
    static let shared = StatsExportService()
    
    private init() {}
    
    func exportToCSV(projectMetrics: [ProjectMetric], fileMetrics: [ProjectMetric], typeMetrics: [ProjectMetric]) -> String {
        var csvContent = ""
        
        // Header
        csvContent += "Project Statistics Export\n"
        csvContent += "Generated: \(Date())\n\n"
        
        // Project Lines of Code
        csvContent += "Lines of Code by Project\n"
        csvContent += "Project Name,Project Type,Lines of Code\n"
        for metric in projectMetrics {
            csvContent += "\"\(metric.projectName)\",\"\(metric.projectType)\",\(metric.value)\n"
        }
        csvContent += "\n"
        
        // File Counts
        csvContent += "Files by Project\n"
        csvContent += "Project Name,Project Type,File Count\n"
        for metric in fileMetrics {
            csvContent += "\"\(metric.projectName)\",\"\(metric.projectType)\",\(metric.value)\n"
        }
        csvContent += "\n"
        
        // Project Types
        csvContent += "Projects by Type\n"
        csvContent += "Project Type,Count\n"
        for metric in typeMetrics {
            csvContent += "\"\(metric.projectName)\",\(metric.value)\n"
        }
        
        return csvContent
    }
    
    func saveExportToFile(content: String, fileName: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = allowedContentTypes(for: fileName)
        panel.nameFieldStringValue = fileName
        
        if panel.runModal() == .OK {
            guard let url = panel.url else {
                return nil
            }

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                NSSound.beep()
                print("Error saving export to file: \(error)")
            }
        }
        return nil
    }

    private func allowedContentTypes(for fileName: String) -> [UTType] {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()

        switch ext {
        case "csv":
            if let csvType = UTType(filenameExtension: "csv") {
                return [csvType]
            }
        case "json":
            return [.json]
        default:
            break
        }

        return [.plainText]
    }
}
