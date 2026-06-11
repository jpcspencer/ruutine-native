import SwiftUI

struct WorkoutCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    let workoutDays: Set<DateComponents>
    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let weekdaySymbols = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    init(workoutDays: Set<DateComponents>, initialMonth: Date = Date()) {
        self.workoutDays = workoutDays
        _displayedMonth = State(initialValue: initialMonth)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                monthHeader
                weekdayHeader
                daysGrid
                legend
            }
            .padding(20)
            .background(RuutineColor.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(RuutineColor.muted)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(RuutineColor.foreground)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(monthYearTitle)
                .font(.bebas(28))
                .foregroundColor(RuutineColor.foreground)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(RuutineColor.foreground)
                    .frame(width: 36, height: 36)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RuutineColor.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        let days = daysInMonth()
        let leadingBlanks = leadingBlankCount()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: 36)
            }

            ForEach(days, id: \.self) { day in
                dayCell(for: day)
            }
        }
    }

    private func dayCell(for day: Int) -> some View {
        let date = dateFor(day: day)
        let hasWorkout = containsWorkout(on: date)
        let isToday = calendar.isDateInToday(date)

        return ZStack {
            if hasWorkout {
                Circle()
                    .fill(RuutineColor.accent)
                    .frame(width: 32, height: 32)
            } else if isToday {
                Circle()
                    .stroke(RuutineColor.accent, lineWidth: 1.5)
                    .frame(width: 32, height: 32)
            }

            Text("\(day)")
                .font(.system(size: 14, weight: hasWorkout ? .bold : .regular))
                .foregroundColor(hasWorkout ? RuutineColor.accentForeground : RuutineColor.foreground)
        }
        .frame(height: 36)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(RuutineColor.accent)
                .frame(width: 8, height: 8)
            Text("Workout completed")
                .font(.system(size: 13))
                .foregroundColor(RuutineColor.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var monthYearTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth).uppercased()
    }

    private func shiftMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private func daysInMonth() -> [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }
        return Array(range)
    }

    private func leadingBlankCount() -> Int {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return weekday - 1
    }

    private func dateFor(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: displayedMonth)
        components.day = day
        return calendar.date(from: components) ?? displayedMonth
    }

    private func containsWorkout(on date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return workoutDays.contains(components)
    }
}
