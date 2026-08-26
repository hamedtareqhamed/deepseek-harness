//
//  ToolCallRow.swift
//  DshMobile
//
//  Renders tool execution status (running spinner, arguments, result card with collapse).
//

import SwiftUI

public struct ToolCallRow: View {
    public let tool: ToolCallItem
    @State private var isExpanded: Bool = false

    public init(tool: ToolCallItem) {
        self.tool = tool
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .foregroundColor(statusColor)
                        .imageScale(.medium)

                    Text(tool.name)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    if tool.isExecuting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if tool.hasError {
                        Text("Error")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    if !tool.arguments.isEmpty && tool.arguments != "{}" {
                        Text("Parameters:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text(tool.arguments)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let result = tool.result, !result.isEmpty {
                        Text("Result:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch tool.name {
        case "bash", "execute": return "terminal"
        case "fs_read", "fs_write", "str_replace_editor": return "doc.text"
        case "web_search", "web_fetch": return "globe"
        case "todo_write": return "checklist"
        default: return "wrench.and.screwdriver"
        }
    }

    private var statusColor: Color {
        if tool.isExecuting { return .blue }
        if tool.hasError { return .red }
        return .green
    }
}
