import SwiftUI

// MARK: - LoginView
// Premium redesign — glass pill inputs, floating options row, refined social buttons

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) var scheme

    @State private var email          = ""
    @State private var password       = ""
    @State private var fullName       = ""
    @State private var phoneNumber    = ""
    @State private var businessName   = ""
    @State private var isSignUp       = false
    @State private var showPassword   = false
    @State private var showResetAlert = false
    @State private var appeared       = false
    @State private var selectedUserType: UserType = .personal

    @FocusState private var focusedField: Field?
    enum Field { case email, password, fullName, phoneNumber, businessName }

    private var accent: Color { AppTheme.baseColor }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Deep atmospheric background
            MeshGradientBackground().ignoresSafeArea()

            // ── Atmospheric center glow
            RadialGradient(
                colors: [accent.opacity(scheme == .dark ? 0.20 : 0.10), .clear],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 0, endRadius: 340)
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 64)

                    // ── Logo
                    logoSection
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.88)
                        .offset(y: appeared ? 0 : 14)

                    Spacer().frame(height: 32)

                    // ── Error banner (global — Google + email errors)
                    if let err = authVM.errorMessage {
                        errorBanner(err)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Sign-up extra fields (name, phone)
                    if isSignUp {
                        signUpExtraFields
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity.combined(with: .scale(scale: 0.96))))
                    }

                    // ── Core fields: email + password
                    coreFields
                        .padding(.horizontal, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 22)

                    // ── Options row: Remember Me + Forgot Password (sign-in only)
                    if !isSignUp {
                        optionsRow
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .opacity(appeared ? 1 : 0)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // ── Account type + business name (sign-up only)
                    if isSignUp {
                        accountTypeSection
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity))
                    }

                    // ── Primary action button
                    primaryButton
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .opacity(appeared ? 1 : 0)

                    // ── Switch mode row
                    toggleRow
                        .padding(.top, 16)
                        .opacity(appeared ? 1 : 0)

                    // ── Divider
                    orDivider
                        .padding(.horizontal, 28)
                        .padding(.vertical, 22)
                        .opacity(appeared ? 1 : 0)

                    // ── Social buttons
                    VStack(spacing: 12) {
                        googleButton
                        appleButton
                    }
                    .padding(.horizontal, 20)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                    Spacer().frame(height: 60)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.40, dampingFraction: 0.80), value: isSignUp)
        .animation(.easeInOut(duration: 0.22), value: authVM.errorMessage)
        .onAppear {
            withAnimation(.spring(response: 0.60, dampingFraction: 0.72).delay(0.10)) {
                appeared = true
            }
        }
        .alert(NSLocalizedString("auth.forgotPassword", comment: ""), isPresented: $showResetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(NSLocalizedString("auth.resetEmailSent", comment: ""))
        }
    }

    // MARK: - Logo ─────────────────────────────────────────────────────

    private var logoSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer diffused ambient glow
                Circle()
                    .fill(RadialGradient(
                        colors: [accent.opacity(scheme == .dark ? 0.60 : 0.28), .clear],
                        center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200)
                    .blur(radius: 32)

                // Soft halo ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [accent.opacity(0.25), accent.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1)
                    .frame(width: 104)
                    .blur(radius: 1.5)

                // Glass disk
                Circle()
                    .fill(scheme == .dark
                          ? AnyShapeStyle(.ultraThinMaterial)
                          : AnyShapeStyle(Color.white.opacity(0.96)))
                    .frame(width: 86, height: 86)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(scheme == .dark ? 0.55 : 0.95),
                                    accent.opacity(0.28)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.0)
                    )
                    .shadow(color: accent.opacity(scheme == .dark ? 0.65 : 0.32), radius: 32, y: 12)
                    .shadow(color: accent.opacity(0.22), radius: 7, y: 3)

                // Icon
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 33, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [accent, AppTheme.accentSecondary],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: 7) {
                Text("ZFlow")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        scheme == .dark
                        ? AnyShapeStyle(LinearGradient(
                            colors: [.white, Color(hex: "#EDE8FF"), accent.opacity(0.80)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(LinearGradient(
                            colors: [accent, AppTheme.accentSecondary],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .tracking(-1.2)
                    .shadow(color: accent.opacity(scheme == .dark ? 0.50 : 0.22), radius: 14, y: 5)

                Text(NSLocalizedString(isSignUp ? "auth.createAccount" : "auth.welcomeBack", comment: ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(scheme == .dark ? Color.white.opacity(0.46) : Color(.secondaryLabel))
            }
        }
    }

    // MARK: - Core Fields (Email + Password) ───────────────────────────

    private var coreFields: some View {
        VStack(spacing: 10) {
            // E-posta
            glassPillField(icon: "envelope.fill", isFocused: focusedField == .email) {
                TextField(NSLocalizedString("auth.email", comment: ""), text: $email)
                    .focused($focusedField, equals: .email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .font(.system(size: 16))
                    .foregroundColor(scheme == .dark ? .white : .primary)
            }

            // Şifre
            glassPillField(icon: "lock.fill", isFocused: focusedField == .password) {
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
                .font(.system(size: 16))
                .foregroundColor(scheme == .dark ? .white : .primary)

                // Eye toggle
                Button { showPassword.toggle(); Haptic.selection() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(scheme == .dark ? Color.white.opacity(0.38) : Color(.tertiaryLabel))
                        .frame(width: 44, height: 44)
                }
            }
        }
    }

    // MARK: - Sign-Up Extra Fields ─────────────────────────────────────

    private var signUpExtraFields: some View {
        VStack(spacing: 10) {
            glassPillField(icon: "person.fill", isFocused: focusedField == .fullName) {
                TextField(NSLocalizedString("auth.fullName", comment: ""), text: $fullName)
                    .focused($focusedField, equals: .fullName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { focusedField = .phoneNumber }
                    .font(.system(size: 16))
                    .foregroundColor(scheme == .dark ? .white : .primary)
            }

            glassPillField(icon: "phone.fill", isFocused: focusedField == .phoneNumber) {
                TextField(NSLocalizedString("auth.phoneNumber", comment: ""), text: $phoneNumber)
                    .focused($focusedField, equals: .phoneNumber)
                    .keyboardType(.phonePad)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .font(.system(size: 16))
                    .foregroundColor(scheme == .dark ? .white : .primary)
            }
        }
    }

    // MARK: - Glass Pill Field ─────────────────────────────────────────

    private func glassPillField<C: View>(
        icon: String,
        isFocused: Bool,
        @ViewBuilder content: () -> C
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    isFocused
                    ? AnyShapeStyle(LinearGradient(
                        colors: [accent, AppTheme.accentSecondary],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(scheme == .dark
                        ? Color.white.opacity(0.32)
                        : Color(.secondaryLabel).opacity(0.65))
                )
                .frame(width: 18)
                .padding(.leading, 18)
                .animation(.easeInOut(duration: 0.20), value: isFocused)

            content()
        }
        .frame(minHeight: 58)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(scheme == .dark
                      ? AnyShapeStyle(.ultraThinMaterial)
                      : AnyShapeStyle(Color.white.opacity(0.93)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(
                    isFocused
                    ? LinearGradient(
                        colors: [accent.opacity(0.75), AppTheme.accentSecondary.opacity(0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(
                        colors: [
                            Color.white.opacity(scheme == .dark ? 0.16 : 0.75),
                            Color.white.opacity(scheme == .dark ? 0.04 : 0.28)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isFocused ? 1.2 : 0.5)
        )
        .shadow(
            color: isFocused
                ? accent.opacity(0.22)
                : Color.black.opacity(scheme == .dark ? 0.22 : 0.06),
            radius: isFocused ? 14 : 6,
            y: isFocused ? 5 : 2)
        .animation(.easeInOut(duration: 0.22), value: isFocused)
    }

    // MARK: - Options Row (Remember Me + Forgot Password) ──────────────

    private var optionsRow: some View {
        HStack(alignment: .center) {
            // ── Remember Me checkbox
            Button { authVM.rememberMe.toggle(); Haptic.selection() } label: {
                HStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(authVM.rememberMe
                                  ? accent
                                  : (scheme == .dark
                                      ? Color.white.opacity(0.10)
                                      : Color(.tertiarySystemFill)))
                            .frame(width: 19, height: 19)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(
                                        authVM.rememberMe
                                            ? accent
                                            : Color.white.opacity(scheme == .dark ? 0.20 : 0.50),
                                        lineWidth: authVM.rememberMe ? 0 : 0.6)
                            )
                        if authVM.rememberMe {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .animation(.spring(response: 0.22, dampingFraction: 0.70), value: authVM.rememberMe)

                    Text(NSLocalizedString("auth.rememberMe", comment: ""))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(scheme == .dark ? Color.white.opacity(0.62) : Color(.secondaryLabel))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // ── Forgot Password
            Button { handleForgotPassword() } label: {
                Text(NSLocalizedString("auth.forgotPassword", comment: ""))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, AppTheme.accentSecondary],
                            startPoint: .leading, endPoint: .trailing)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Account Type Section ─────────────────────────────────────

    private var accountTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("auth.accountType", comment: ""))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(scheme == .dark ? Color.white.opacity(0.36) : Color(.tertiaryLabel))
                .textCase(.uppercase)
                .tracking(0.7)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                ForEach(UserType.allCases, id: \.self) { accountTypeChip($0) }
            }

            if selectedUserType == .business {
                glassPillField(icon: "building.2.fill", isFocused: focusedField == .businessName) {
                    TextField(NSLocalizedString("auth.businessName", comment: ""), text: $businessName)
                        .focused($focusedField, equals: .businessName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.system(size: 16))
                        .foregroundColor(scheme == .dark ? .white : .primary)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func accountTypeChip(_ type: UserType) -> some View {
        let sel = selectedUserType == type
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.70)) { selectedUserType = type }
            Haptic.selection()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: sel ? .semibold : .regular))
                Text(NSLocalizedString(type == .personal ? "auth.personal" : "auth.business", comment: ""))
                    .font(.system(size: 14, weight: sel ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(sel
                          ? AnyShapeStyle(LinearGradient(
                              colors: [accent.opacity(0.20), AppTheme.accentSecondary.opacity(0.12)],
                              startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(scheme == .dark
                              ? Color.white.opacity(0.06)
                              : Color(.tertiarySystemFill)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        sel ? accent.opacity(0.55) : Color.white.opacity(scheme == .dark ? 0.10 : 0.40),
                        lineWidth: sel ? 1.2 : 0.5)
            )
            .foregroundColor(sel ? accent : (scheme == .dark ? Color.white.opacity(0.58) : Color(.secondaryLabel)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error Banner ─────────────────────────────────────────────

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(ZColor.expense)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ZColor.expense)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button { authVM.errorMessage = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ZColor.expense.opacity(0.70))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ZColor.expense.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ZColor.expense.opacity(0.22), lineWidth: 0.5))
        )
    }

    // MARK: - Primary Button ───────────────────────────────────────────

    private var primaryButton: some View {
        let active = !isFormInvalid && !authVM.isLoading

        return Button { performAuth() } label: {
            ZStack {
                if authVM.isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: isSignUp ? "person.badge.plus" : "arrow.right.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text(NSLocalizedString(isSignUp ? "auth.createAccount" : "auth.signIn", comment: ""))
                            .font(.system(size: 17, weight: .bold))
                            .tracking(0.2)
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                ZStack {
                    // Base gradient
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(active
                              ? AnyShapeStyle(LinearGradient(
                                  colors: [accent, AppTheme.accentSecondary],
                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(LinearGradient(
                                  colors: [accent.opacity(0.35), AppTheme.accentSecondary.opacity(0.28)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)))

                    // Inner top highlight shimmer (active only)
                    if active {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.20), .clear],
                                startPoint: .top, endPoint: .center))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(active ? 0.18 : 0), lineWidth: 0.7)
            )
            // Double-layer shadow for depth
            .shadow(color: active ? accent.opacity(0.58) : .clear, radius: 22, y: 9)
            .shadow(color: active ? accent.opacity(0.28) : .clear, radius: 6, y: 3)
        }
        .disabled(isFormInvalid || authVM.isLoading)
        .buttonStyle(FABButtonStyle())
        .animation(.easeInOut(duration: 0.18), value: isFormInvalid)
    }

    // MARK: - Toggle Row ───────────────────────────────────────────────

    private var toggleRow: some View {
        HStack(spacing: 4) {
            Text(NSLocalizedString(isSignUp ? "auth.haveAccount" : "auth.noAccount", comment: ""))
                .font(.system(size: 14))
                .foregroundColor(scheme == .dark ? Color.white.opacity(0.44) : Color(.secondaryLabel))
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
            .foregroundColor(accent)
        }
    }

    // MARK: - OR Divider ───────────────────────────────────────────────

    private var orDivider: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(scheme == .dark ? Color.white.opacity(0.08) : Color(.separator).opacity(0.30))
                .frame(height: 0.5)
            Text(NSLocalizedString("auth.orDivider", comment: ""))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(scheme == .dark ? Color.white.opacity(0.26) : Color(.tertiaryLabel))
                .fixedSize()
                .padding(.horizontal, 4)
            Rectangle()
                .fill(scheme == .dark ? Color.white.opacity(0.08) : Color(.separator).opacity(0.30))
                .frame(height: 0.5)
        }
    }

    // MARK: - Google Button ────────────────────────────────────────────

    private var googleButton: some View {
        Button {
            Haptic.medium()
            Task { await authVM.signInWithGoogle() }
        } label: {
            HStack(spacing: 0) {
                // ── G icon
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                        .shadow(color: Color.black.opacity(0.14), radius: 4, y: 2)
                    Text("G")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#4285F4"))
                }
                .padding(.leading, 18)

                // ── Label (centred)
                Text(NSLocalizedString("auth.continueWithGoogle", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(scheme == .dark ? .white : Color(.label))
                    .frame(maxWidth: .infinity)

                // ── Loading / spacer
                Group {
                    if authVM.isLoading {
                        ProgressView()
                            .scaleEffect(0.78)
                            .tint(scheme == .dark ? .white : Color(.secondaryLabel))
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 46)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(scheme == .dark
                          ? AnyShapeStyle(.ultraThinMaterial)
                          : AnyShapeStyle(Color.white))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(scheme == .dark ? 0.24 : 0.85),
                                Color.white.opacity(scheme == .dark ? 0.05 : 0.30)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(scheme == .dark ? 0.26 : 0.08), radius: 18, y: 7)
        }
        .buttonStyle(FABButtonStyle())
        .disabled(authVM.isLoading)
    }

    // MARK: - Apple Button ─────────────────────────────────────────────

    private var appleButton: some View {
        Button {
            Haptic.medium()
            Task { await authVM.signInWithApple() }
        } label: {
            HStack(spacing: 0) {
                // ── Apple icon
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 46)
                    .padding(.leading, 4)

                // ── Label (centred)
                Text(NSLocalizedString("auth.continueWithApple", comment: ""))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                // ── Loading indicator or spacer
                Group {
                    if authVM.isLoading {
                        ProgressView()
                            .scaleEffect(0.78)
                            .tint(.white)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 46)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(scheme == .dark
                              ? AnyShapeStyle(Color(hex: "0C0C0C").opacity(0.85))
                              : AnyShapeStyle(Color.black))
                    // Subtle top highlight
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.white.opacity(0.07), .clear],
                            startPoint: .top, endPoint: .center))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.38), radius: 18, y: 7)
        }
        .buttonStyle(FABButtonStyle())
        .disabled(authVM.isLoading)
    }

    // MARK: - Helpers ──────────────────────────────────────────────────


    private var isFormInvalid: Bool {
        if isSignUp {
            let base = email.isEmpty || password.isEmpty || fullName.isEmpty || password.count < 6
            return selectedUserType == .business
                ? base || businessName.trimmingCharacters(in: .whitespaces).isEmpty
                : base
        }
        return email.isEmpty || password.isEmpty
    }

    private func performAuth() {
        guard !isFormInvalid else { return }
        Haptic.medium(); focusedField = nil
        Task {
            if isSignUp {
                await authVM.signUp(
                    email: email, password: password, fullName: fullName,
                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                    userType: selectedUserType,
                    businessName: selectedUserType == .business ? businessName : nil)
            } else {
                await authVM.signIn(email: email, password: password)
            }
        }
    }

    private func handleForgotPassword() {
        guard !email.isEmpty else {
            authVM.errorMessage = NSLocalizedString("auth.enterEmailFirst", comment: "")
            return
        }
        Haptic.medium()
        Task {
            let success = await authVM.sendPasswordResetEmail(email: email)
            if success { showResetAlert = true }
        }
    }
}

#Preview {
    LoginView().environmentObject(AuthViewModel())
}
