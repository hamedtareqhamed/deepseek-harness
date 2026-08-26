//
//  ApprovalSheet.swift
//  DshMobile
//
//  Modal prompt displayed when the agent requests user approval for dangerous/important tool actions.
//

import SwiftUI

public struct ApprovalSheet: View {
    public let approval: ApprovalRequest
    public let onDecision: (String) -> Void

    public init(approval: ApprovalRequest, onDecision: @escaping (String) -> Void) {
        self.approval = approval
        self.onDecision = onDecision
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.orange)
                .padding(.top, 20)

            Text("Action Requires Approval")
                .font(.title2)
                .fontWeight(.bold)

            if let tool = approval.toolName {
                HStack {
                    Text("Tool:")
                        .fontWeight(.semibold)
                    Text(tool)
                        .font(.system(.body, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }

            Text(approval.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.primary)

            Spacer()

            HStack(spacing: 16) {
                Button(action: { onDecision("reject") }) {
                    Text("Reject")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: { onDecision("allow") }) {
                    Text("Allow")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }
}
