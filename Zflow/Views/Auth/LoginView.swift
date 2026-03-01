import SwiftUI

// MARK: - Login View
// Elite auth screen — Liquid Glass on night backdrop

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) var scheme

    @State private var email        = ""
    @State private var password     = ""
    @State private var fullName     = ""
    @State private var businessName = ""
    @State private var isSignUp     = false
    @State private var selectedUserType: UserType = .personal
    @State private var showPassword = false
    @State private var appeared     = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password, fullName, businessName }

    var body: some View {
        ZStack {
            // Reuse LiquidNightBackground but lighter in light mode
            AuthBackground(scheme: scheme)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 64)

                    // Logo
                    logoSection
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.85)
                        .offset(y: appeared ? 0 : 20)

                    Spacer().frame(height: 36)

                    // Form glass card
                    formCard
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 30)

                    // Error
                    if let err = authVM.errorMessage {
                        errorBanner(err)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Primary CTA
                    primaryButton
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)

                    // Toggle row
                    toggleRow
                        .padding(.top, 18)
                        .padding(.bottom, 50)
                        .opacity(appeared ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.40, dampingFraction: 0.80), value: isSignUp)
        .animation(.easeInOut(duration: 0.22), value: authVM.errorMessage)
        .onAppear {
            withAnimation(.spring(response: 0.60, dampingFraction: 0.72).delay(0.12)) {
                appeared = true
            }
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#5E5CE6").opacity(scheme == .dark ? 0.50 : 0.25), .clear],
                            center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 160)
                    .blur(radius: 20)

                // Glass circle
                ZStack {
                    Circle()
                        .fill(scheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.92)))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.4), Color(hex: "#5E5CE6").opacity(0.2)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 0.8)
                        )
                        .shadow(color: Color(hex: "#5E5CE6").opacity(0.55), radius: 24, y: 8)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }

            VStack(spacing: 6) {
                Text("ZFlow")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(
                        scheme == .dark
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color.white, Color(hex: "#C4B5FD"), Color(hex: "#818CF8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .tracking(-0.8)

                Text(NSLocalizedString(isSignUp ? "auth.createAccount" : "auth.welcomeBack", comment: ""))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(scheme == .dark ? Color.white.opacity(0.50) : Color(.secondaryLabel))
            }
        }
    }

    // MARK: - Form Card (Liquid Glass)

    private var formCard: some View {
        VStack(spacing: 0) {
            // Full name
            if isSignUp {
                formRow(icon: "person.fill", content: {
                    TextField(NSLocalizedString("auth.fullName", comment: ""), text: $fullName)
                        .focused($focusedField, equals: .fullName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .onSubmit { focusedField = .email }
                })
                formDivider()
            }

            // Email
            formRow(icon: "envelope.fill", content: {
                TextField(NSLocalizedString("auth.email", comment: ""), text: $email)
                    .focused($focusedField, equals: .email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
            })
            formDivider()

            // Password
            formRow(icon: "lock.fill", content: {
                Group {
                    if showPassword {
                        TextField(NSLocalizedString("auth.password", comment: ""), text: $password)
                    } else {
                        SecureField(NSLocalizedString("auth.password", comment: ""), text: $password)
                    }
                }
                .focused($focusedField, equals: .password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(isSignUp ? .next : .go)
                .onSubmit { if !isSignUp { performAuth() } }

                Spacer()

                Button {
                    showPassword.toggle()
                    Haptic.selection()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(scheme == .dark ? Color.white.opacity(0.45) : Color(.tertiaryLabel))
                        .frame(width: 40, height: 40)
                }
            })

            // Remember me (sign in)
            if !isSignUp {
                formDivider()
                rememberMeRow
            }

            // Account type (sign up)
            if isSignUp {
                formDivider()
                accountTypeRow
            }

            // Business name
            if isSignUp && selectedUserType == .business {
                formDivider()
                formRow(icon: "building.2.fill", content: {
                    TextField(NSLocalizedString("auth.businessName", comment: ""), text: $businessName)
                        .focused($focusedField, equals: .businessName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                })
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(scheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.94)))
                .shadow(
                    color: scheme == .dark
                        ? Color(hex: "#5E5CE6").opacity(0.15)
                        : Color.black.opacity(0.07),
                    radius: 24, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    scheme == .dark
                        ? LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.03)],
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(
                            colors: [Color.white.opacity(0.8), Color(.systemGray5).opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8)
        )
    }

    private func formRow<C: View>(icon: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(scheme == .dark ? Color.white.opacity(0.40) : Color(.secondaryLabel))
                .frame(width: 18)
                .padding(.leading, 16)

            content()
                .font(.system(size: 16))
                .foregroundColor(scheme == .dark ? .white : .primary)
        }
        .frame(minHeight: 52)
    }

    private func formDivider() -> some View {
        Rectangle()
            .fill(scheme == .dark ? Color.white.opacity(0.07) : Color(.separator).opacity(0.4))
            .frame(height: 0.5)
            .padding(.leading, 46)
    }

    // MARK: - Remember Me

    private var rememberMeRow: some View {
        Button {
            authVM.rememberMe.toggle()
            Haptic.selection()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: authVM.rememberMe ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(authVM.rememberMe ? ZColor.indigo : (scheme == .dark ? Color.white.opacity(0.35) : Color(.tertiaryLabel)))
                    .padding(.leading, 16)

                Text(NSLocalizedString("auth.rememberMe", comment: ""))
                    .font(.system(size: 15))
                    .foregroundColor(scheme == .dark ? Color.white.opacity(0.75) : .primary)

                Spacer()
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: authVM.rememberMe)
    }

    // MARK: - Account Type

    private var accountTypeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("auth.accountType", comment: ""))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(scheme == .dark ? Color.white.opacity(0.40) : Color(.tertiaryLabel))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            HStack(spacing: 10) {
                ForEach(UserType.allCases, id: \.self) { type in
                    accountTypeChip(type)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity))
    }

    private func accountTypeChip(_ type: UserType) -> some View {
        let sel = selectedUserType == type
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { selectedUserType = type }
            Haptic.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: sel ? .semibold : .regular))
                Text(NSLocalizedString(type == .personal ? "auth.personal" : "auth.business", comment: ""))
                    .font(.system(size: 14, weight: sel ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(sel
                          ? ZColor.indigo.opacity(0.15)
                          : (scheme == .dark ? Color.white.opacity(0.07) : Color(.tertiarySystemFill)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(sel ? ZColor.indigo.opacity(0.55) : .clear, lineWidth: 1.5)
            )
            .foregroundColor(sel ? ZColor.indigo : (scheme == .dark ? Color.white.opacity(0.65) : Color(.secondaryLabel)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(ZColor.expense)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ZColor.expense)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ZColor.expense.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(ZColor.expense.opacity(0.22), lineWidth: 0.5))
        )
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button { performAuth() } label: {
            ZStack {
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: isSignUp ? "person.badge.plus" : "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(NSLocalizedString(isSignUp ? "auth.createAccount" : "auth.signIn", comment: ""))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isFormInvalid || authVM.isLoading
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "#5E5CE6").opacity(0.40), Color(hex: "#7D7AFF").opacity(0.40)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "#5E5CE6"), Color(hex: "#7D7AFF")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            )
            .shadow(
                color: isFormInvalid ? .clear : Color(hex: "#5E5CE6").opacity(0.45),
                radius: 16, y: 6)
        }
        .disabled(isFormInvalid || authVM.isLoading)
        .buttonStyle(FABButtonStyle())
        .animation(.easeInOut(duration: 0.18), value: isFormInvalid)
        .accessibilityLabel(NSLocalizedString(isSignUp ? "auth.createAccount" : "auth.signIn", comment: ""))
    }

    // MARK: - Toggle

    private var toggleRow: some View {
        HStack(spacing: 4) {
            Text(NSLocalizedString(isSignUp ? "auth.haveAccount" : "auth.noAccount", comment: ""))
                .font(.system(size: 14))
                .foregroundColor(scheme == .dark ? Color.white.opacity(0.45) : Color(.secondaryLabel))
            Button(NSLocalizedString(isSignUp ? "auth.signIn" : "auth.signUp", comment: "")) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.80)) {
                    isSignUp.toggle()
                    authVM.errorMessage = nil
                    businessName = ""
                    selectedUserType = .personal
                }
                Haptic.selection()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(ZColor.indigo)
            .accessibilityLabel(NSLocalizedString(isSignUp ? "auth.signIn" : "auth.signUp", comment: ""))
        }
    }

    // MARK: - Helpers

    private var isFormInvalid: Bool {
        if isSignUp {
            let base = email.isEmpty || password.isEmpty || fullName.isEmpty || password.count < 6
            if selectedUserType == .business {
                return base || businessName.trimmingCharacters(in: .whitespaces).isEmpty
            }
            return base
        }
        return email.isEmpty || password.isEmpty
    }

    private func performAuth() {
        guard !isFormInvalid else { return }
        Haptic.medium()
        focusedField = nil
        Task {
            if isSignUp {
                await authVM.signUp(
                    email: email, password: password, fullName: fullName,
                    userType: selectedUserType,
                    businessName: selectedUserType == .business ? businessName : nil)
            } else {
                await authVM.signIn(email: email, password: password)
            }
        }
    }
}

// MARK: - Auth Background

struct AuthBackground: View {
    let scheme: ColorScheme
    @State private var a = false

    var body: some View {
        ZStack {
            if scheme == .dark {
                // Night mode — match onboarding
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#000000"), location: 0),
                        .init(color: Color(hex: "#060614"), location: 0.55),
                        .init(color: Color(hex: "#020208"), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: "#5E5CE6").opacity(0.55), .clear],
                        center: .center, startRadius: 0, endRadius: 200))
                    .frame(width: 400).blur(radius: 70)
                    .offset(x: a ? -60 : -110, y: a ? -240 : -300)
                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: a)

                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: "#7C3AED").opacity(0.38), .clear],
                        center: .center, startRadius: 0, endRadius: 160))
                    .frame(width: 320).blur(radius: 65)
                    .offset(x: a ? 100 : 60, y: a ? -90 : -140)
                    .animation(.easeInOut(duration: 13).repeatForever(autoreverses: true), value: a)

                Circle()
                    .fill(RadialGradient(
                        colors: [Color(hex: "#059669").opacity(0.16), .clear],
                        center: .center, startRadius: 0, endRadius: 150))
                    .frame(width: 300).blur(radius: 90)
                    .offset(x: a ? -70 : -30, y: a ? 450 : 380)
                    .animation(.easeInOut(duration: 15).repeatForever(autoreverses: true), value: a)

            } else {
                // Light mode — clean, airy
                Color(.systemGroupedBackground).ignoresSafeArea()

                Circle()
                    .fill(Color(hex: "#5E5CE6").opacity(0.06))
                    .frame(width: 360).blur(radius: 90)
                    .offset(x: a ? -40 : -80, y: a ? -160 : -220)
                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: a)

                Circle()
                    .fill(Color(hex: "#7C3AED").opacity(0.04))
                    .frame(width: 280).blur(radius: 80)
                    .offset(x: a ? 80 : 40, y: a ? 300 : 380)
                    .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: a)
            }
        }
        .onAppear { a = true }
    }
}
