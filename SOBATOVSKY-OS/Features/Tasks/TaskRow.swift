import SwiftUI

extension TaskPriority {
    var tint: Color {
        switch self {
        case .low: return SB.muted
        case .normal: return SB.silver
        case .high: return SB.warning
        case .critical: return SB.error
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject var store: AppStore
    let task: TaskItem
    var compact = false
    var onOpen: () -> Void

    var body: some View {
        let overdue = task.isOverdue()
        SBCard(padding: 14, radius: 16, stroke: overdue ? SB.error.opacity(0.5) : SB.border) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    Haptics.tap()
                    withAnimation(SBMotion.anim) { store.toggleTask(task.id) }
                } label: {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26))
                        .foregroundStyle(task.isDone ? SB.success : (overdue ? SB.error : SB.silver))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone ? "Отменить выполнение: \(task.title)" : "Выполнить: \(task.title)")

                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.sb(16, .medium))
                            .foregroundStyle(task.isDone ? SB.muted : SB.white)
                            .strikethrough(task.isDone)
                            .multilineTextAlignment(.leading)
                        if !compact && !task.details.isEmpty {
                            Text(task.details).font(.sb(13)).foregroundStyle(SB.silver)
                                .lineLimit(2).multilineTextAlignment(.leading)
                        }
                        HStack(spacing: 8) {
                            if let d = task.dueDate {
                                HStack(spacing: 4) {
                                    Image(systemName: task.hasTime ? "clock" : "calendar").font(.system(size: 11))
                                    Text(Fmt.dueText(d, hasTime: task.hasTime)).font(.sb(12)).lineLimit(1)
                                }
                                .foregroundStyle(overdue ? SB.error : SB.silver)
                            }
                            if task.priority != .normal {
                                HStack(spacing: 3) {
                                    Image(systemName: "flag.fill").font(.system(size: 10))
                                    Text(task.priority.title).font(.sb(11, .medium))
                                }
                                .foregroundStyle(task.priority.tint)
                            }
                            Spacer(minLength: 0)
                            Text("+\(task.xp) XP").font(.sb(11, .medium)).monospacedDigit().foregroundStyle(SB.muted)
                        }
                        if !compact {
                            let sub = [store.subjectName(task.subjectID), task.category.isEmpty ? nil : task.category]
                                .compactMap { $0 }.joined(separator: " · ")
                            if !sub.isEmpty || overdue {
                                HStack(spacing: 6) {
                                    if overdue { Tag(text: "Просрочено", tint: SB.error) }
                                    if !sub.isEmpty { Text(sub).font(.sb(12)).foregroundStyle(SB.muted).lineLimit(1) }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(task.isDone ? 0.8 : 1)
    }
}
