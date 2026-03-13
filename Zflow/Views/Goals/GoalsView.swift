// ============================================================
// ZFlow — GoalsView + AddGoalSheet
// ============================================================

import SwiftUI

// MARK: - GoalsView

struct GoalsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var goalVM: GoalViewModel
    @Environment(\.colorScheme) var scheme

    @State private var showAddGoal   = false
    @State private var selectedGoal: Goal?
    @State private var showContribute = false
    @State private var contributeAmount = ""

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()

                if goalVM.isLoading && goalVM.goals.isEmpty {
                    ProgressView().tint(AppTheme.baseColor)
                } else if goalVM.goals.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(goalVM.goals) { goal in
                                GoalCard(goal: goal)
                                    .onTapGesture {
                                        selectedGoal = goal
                                        showContribute = true
                                        Haptic.light()
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task {
                                                if let uid = authVM.currentUserId {
                                                    await goalVM.deleteGoal(id: goal.id, userId: uid)
                                                }
                                            }
                                        } label: {
                                            Label("Sil", systemImage: "trash.fill")
                                        }
                                    }
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 85)
                    }
                }
            }
            .navigationTitle("Hedeflerim")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddGoal = true; Haptic.light()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.baseColor)
                    }
                }
            }
            .sheet(isPresented: $showAddGoal) {
                AddGoalSheet()
                    .environmentObject(authVM)
                    .environmentObject(goalVM)
            }
            .sheet(item: $selectedGoal) { goal in
                ContributeSheet(goal: goal, amount: $contributeAmount)
                    .environmentObject(authVM)
                    .environmentObject(goalVM)
                    .presentationDetents([.height(280)])
            }
            .task {
                if let uid = authVM.currentUserId {
                    await goalVM.fetchGoals(userId: uid)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(
                    colors: [AppTheme.baseColor, AppTheme.accentSecondary],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Henüz hedef yok")
                .font(.system(size: 20, weight: .bold))

            Text("+ butonuna basarak ilk finansal hedefini ekle.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal
    @Environment(\.colorScheme) var scheme

    var accentColor: Color { Color(hex: goal.colorHex) }

    var body: some View {
        GradientCard(gradient: LinearGradient(
            colors: [accentColor.opacity(0.18), accentColor.opacity(0.06)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ), cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    // Icon
                    Text(goal.icon)
                        .font(.system(size: 26))
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(accentColor.opacity(0.15)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(goal.title)
                            .font(.system(size: 16, weight: .bold))
                        if let deadline = goal.deadline {
                            Text(deadline, style: .date)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    // Percentage badge
                    Text("\(Int(goal.percentage))%")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(accentColor.opacity(0.12)))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(goal.percentage / 100), height: 8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: goal.percentage)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(formatCurrency(goal.currentAmount)) biriktirdin")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(formatCurrency(goal.remaining)) kaldı")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(accentColor)
                }
            }
            .padding(16)
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "₺"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "₺0"
    }
}

// MARK: - Add Goal Sheet

struct AddGoalSheet: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var goalVM: GoalViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title       = ""
    @State private var targetAmount = ""
    @State private var selectedIcon = "⭐"
    @State private var selectedColor = "#5E5CE6"
    @State private var hasDeadline  = false
    @State private var deadline     = Date().addingTimeInterval(86400 * 90)
    @State private var isSaving     = false

    private let icons = ["⭐","🏠","🚗","✈️","💻","📱","🎓","💍","🏖️","💰","🎯","🏋️","🎁","🏥","🐾"]
    private let colors = ["#5E5CE6","#0A84FF","#30D158","#FF9F0A","#FF375F","#BF5AF2","#00C7BE","#FF6B6B"]

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Icon picker
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Hedef İkonu")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                                ForEach(icons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon; Haptic.selection()
                                    } label: {
                                        Text(icon)
                                            .font(.system(size: 24))
                                            .frame(width: 40, height: 40)
                                            .background(Circle().fill(selectedIcon == icon ? AppTheme.baseColor.opacity(0.15) : Color(.systemGray6)))
                                            .overlay(Circle().strokeBorder(selectedIcon == icon ? AppTheme.baseColor : .clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Renk")
                            HStack(spacing: 12) {
                                ForEach(colors, id: \.self) { hex in
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 30, height: 30)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: selectedColor == hex ? 2.5 : 0))
                                        .scaleEffect(selectedColor == hex ? 1.15 : 1.0)
                                        .onTapGesture { selectedColor = hex; Haptic.selection() }
                                        .animation(.spring(response: 0.25), value: selectedColor)
                                }
                            }
                        }

                        // Title field
                        GlassCard(cornerRadius: 14) {
                            TextField("Hedef adı (örn: Tatil fonu)", text: $title)
                                .font(.system(size: 15))
                                .padding(14)
                        }

                        // Target amount field
                        GlassCard(cornerRadius: 14) {
                            HStack {
                                Text("₺")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(AppTheme.baseColor)
                                TextField("Hedef tutar", text: $targetAmount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16))
                            }
                            .padding(14)
                        }

                        // Deadline toggle
                        GlassCard(cornerRadius: 14) {
                            VStack(spacing: 0) {
                                Toggle("Son tarih ekle", isOn: $hasDeadline)
                                    .padding(14)
                                if hasDeadline {
                                    Divider().padding(.leading, 14)
                                    DatePicker("Son tarih", selection: $deadline, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }

                        // Save button
                        Button {
                            saveGoal()
                        } label: {
                            ZStack {
                                if isSaving { ProgressView().tint(.white) }
                                else { Text("Hedef Ekle").font(.system(size: 16, weight: .bold)).foregroundColor(.white) }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 16).fill(
                                title.isEmpty || targetAmount.isEmpty
                                ? AnyShapeStyle(Color.gray.opacity(0.3))
                                : AnyShapeStyle(LinearGradient(
                                    colors: [AppTheme.baseColor, AppTheme.accentSecondary],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                            ))
                        }
                        .disabled(title.isEmpty || targetAmount.isEmpty || isSaving)
                        .buttonStyle(.plain)
                        .padding(.bottom, 20)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Yeni Hedef")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.leading, 4)
    }

    private func saveGoal() {
        guard let uid = authVM.currentUserId,
              let amount = Double(targetAmount.replacingOccurrences(of: ",", with: "."))
        else { return }
        isSaving = true
        Task {
            await goalVM.addGoal(
                userId: uid, title: title,
                target: amount, icon: selectedIcon,
                color: selectedColor,
                deadline: hasDeadline ? deadline : nil
            )
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Contribute Sheet

struct ContributeSheet: View {
    let goal: Goal
    @Binding var amount: String
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var goalVM: GoalViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("💰 \(goal.title)'a katkı ekle")
                .font(.system(size: 18, weight: .bold))
                .padding(.top, 20)

            HStack {
                Text("₺")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppTheme.baseColor)
                TextField("Tutar", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 20, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
            .padding(.horizontal)

            Button {
                guard let uid = authVM.currentUserId,
                      let val = Double(amount.replacingOccurrences(of: ",", with: "."))
                else { return }
                Task {
                    await goalVM.contribute(goal: goal, amount: val, userId: uid)
                    dismiss()
                }
            } label: {
                Text("Ekle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.baseColor))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
}
