const fs = require('fs');

function fix_modals(content) {
    // Fix LoginModal definition
    content = content.replace(
        /class LoginModal extends StatefulWidget \{\s*final void Function\(String\) onLogin;\s*const LoginModal\(\{super\.key, required this\.onLogin\}\);/g,
        'class LoginModal extends StatefulWidget {\\n  final void Function(String) onLogin;\\n  final bool isTagalog;\\n\\n  const LoginModal({super.key, required this.onLogin, this.isTagalog = true});'
    );
    // Fix SignupModal definition
    content = content.replace(
        /class SignupModal extends StatefulWidget \{\s*final void Function\(String\) onSignup;\s*const SignupModal\(\{super\.key, required this\.onSignup\}\);/g,
        'class SignupModal extends StatefulWidget {\\n  final void Function(String) onSignup;\\n  final bool isTagalog;\\n\\n  const SignupModal({super.key, required this.onSignup, this.isTagalog = true});'
    );

    // Login Modal titles and texts
    content = content.replace(/'Mag-log in'/g, "widget.isTagalog ? 'Mag-log in' : 'Log In'");
    content = content.replace(/'Welcome back to our community'/g, "widget.isTagalog ? 'Maligayang pagbabalik sa ating komunidad' : 'Welcome back to our community'");
    content = content.replace(/'Welcome back to Sto\. Rosario Parish Church'/g, "widget.isTagalog ? 'Maligayang pagbabalik sa Sto. Rosario Parish Church' : 'Welcome back to Sto. Rosario Parish Church'");

    // Signup Modal titles and texts
    content = content.replace(/'Mag-sign up'/g, "widget.isTagalog ? 'Mag-sign up' : 'Sign Up'");
    content = content.replace(/'Join our spiritual community'/g, "widget.isTagalog ? 'Sumali sa ating espirituwal na komunidad' : 'Join our spiritual community'");

    // Form field labels and placeholders
    content = content.replace(/'Email Address'/g, "widget.isTagalog ? 'Email' : 'Email Address'");
    content = content.replace(/'Enter your email'/g, "widget.isTagalog ? 'Ilagay ang iyong email' : 'Enter your email'");
    content = content.replace(/'Password'/g, "widget.isTagalog ? 'Password' : 'Password'");
    content = content.replace(/'Create a password'/g, "widget.isTagalog ? 'Gumawa ng password' : 'Create a password'");
    content = content.replace(/'Confirm Password'/g, "widget.isTagalog ? 'Kumpirmahin ang Password' : 'Confirm Password'");
    content = content.replace(/'Confirm your password'/g, "widget.isTagalog ? 'Kumpirmahin ang iyong password' : 'Confirm your password'");
    content = content.replace(/'Full Name'/g, "widget.isTagalog ? 'Buong Pangalan' : 'Full Name'");
    content = content.replace(/'Enter your full name'/g, "widget.isTagalog ? 'Ilagay ang iyong buong pangalan' : 'Enter your full name'");
    content = content.replace(/'Forgot Password\?'/g, "widget.isTagalog ? 'Nakalimutan ang Password?' : 'Forgot Password?'");

    // Terms checkbox
    content = content.replace(/'I accept the Terms and Conditions'/g, "widget.isTagalog ? 'Tinatanggap ko ang mga Tuntunin at Kundisyon' : 'I accept the Terms and Conditions'");

    return content;
}

let dash_content = fs.readFileSync('c:/src/parish_church/sto_rosario_parish_church/lib/parishioner_dashboard.dart', 'utf8');

dash_content = dash_content.replace(/return SignupModal\(onSignup: _navigateToDashboardFromAuth\);/g, "return SignupModal(onSignup: _navigateToDashboardFromAuth, isTagalog: _isLanguageTagalog);");
dash_content = dash_content.replace(/return LoginModal\(onLogin: _navigateToDashboardFromAuth\);/g, "return LoginModal(onLogin: _navigateToDashboardFromAuth, isTagalog: _isLanguageTagalog);");

dash_content = dash_content.replace(
    /'Welcome to Sto\. Rosario Parish Church'/g, 
    "_isLanguageTagalog ? 'Maligayang pagdating sa Sto. Rosario Parish Church' : 'Welcome to Sto. Rosario Parish Church'"
);

dash_content = dash_content.replace(
    /child: const Text\(\s*'Mag-sign up'/g,
    "child: Text(\\n                      _isLanguageTagalog ? 'Mag-sign up' : 'Sign Up'"
);
dash_content = dash_content.replace(
    /child: const Text\(\s*'Mag-log in'/g,
    "child: Text(\\n                      _isLanguageTagalog ? 'Mag-log in' : 'Log In'"
);

dash_content = fix_modals(dash_content);
fs.writeFileSync('c:/src/parish_church/sto_rosario_parish_church/lib/parishioner_dashboard.dart', dash_content);


let land_content = fs.readFileSync('c:/src/parish_church/sto_rosario_parish_church/lib/features/auth/landing_page.dart', 'utf8');

if (!land_content.includes("bool _isTagalog = true;")) {
    land_content = land_content.replace("class _LandingPageState extends State<LandingPage> {", "class _LandingPageState extends State<LandingPage> {\\n  bool _isTagalog = true;");
}

land_content = land_content.replace(/return SignupModal\(onSignup: _navigateToDashboard\);/g, "return SignupModal(onSignup: _navigateToDashboard, isTagalog: _isTagalog);");
land_content = land_content.replace(/return LoginModal\(onLogin: _navigateToDashboard\);/g, "return LoginModal(onLogin: _navigateToDashboard, isTagalog: _isTagalog);");

land_content = land_content.replace(
    /'Log In'/g, 
    "_isTagalog ? 'Mag-log in' : 'Log In'"
);
land_content = land_content.replace(
    /'Sign Up'/g, 
    "_isTagalog ? 'Mag-sign up' : 'Sign Up'"
);
land_content = land_content.replace(
    /'Continue as Guest'/g, 
    "_isTagalog ? 'Magpatuloy bilang Bisita' : 'Continue as Guest'"
);
land_content = land_content.replace(
    /'Welcome to our spiritual community'/g, 
    "_isTagalog ? 'Maligayang pagdating sa ating espirituwal na komunidad' : 'Welcome to our spiritual community'"
);

land_content = land_content.replace(/child: const Text\(\s*'Sign Up'/g, "child: Text(\\n                              _isTagalog ? 'Mag-sign up' : 'Sign Up'");
land_content = land_content.replace(/child: const Text\(\s*'Log In'/g, "child: Text(\\n                              _isTagalog ? 'Mag-log in' : 'Log In'");

const toggle_code = `
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      icon: const Icon(Icons.language, color: Colors.white, size: 30),
                      onPressed: () {
                        setState(() { _isTagalog = !_isTagalog; });
                      },
                    ),
                  ),
                ),
`;

if (!land_content.includes("Alignment.topRight")) {
    land_content = land_content.replace("SafeArea(\\n            child: Column(", "SafeArea(\\n            child: Stack(\\n              children: [\\n                Column(");
    land_content = land_content.replace("© 2026 Sto. Rosario Parish Church',\\n                    style: TextStyle(color: ParishColors.blue200, fontSize: 12),\\n                  ),\\n                ),\\n              ],", "© 2026 Sto. Rosario Parish Church',\\n                    style: TextStyle(color: ParishColors.blue200, fontSize: 12),\\n                  ),\\n                ),\\n              ],\\n            ),\\n" + toggle_code + "\\n              ],");
}

land_content = fix_modals(land_content);

fs.writeFileSync('c:/src/parish_church/sto_rosario_parish_church/lib/features/auth/landing_page.dart', land_content);

console.log("Done");
