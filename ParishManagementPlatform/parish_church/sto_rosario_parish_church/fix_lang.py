import re

def fix_modals(content):
    # Fix LoginModal definition
    content = re.sub(
        r'class LoginModal extends StatefulWidget \{\s*final void Function\(String\) onLogin;\s*const LoginModal\(\{super\.key, required this\.onLogin\}\);',
        r'class LoginModal extends StatefulWidget {\n  final void Function(String) onLogin;\n  final bool isTagalog;\n\n  const LoginModal({super.key, required this.onLogin, this.isTagalog = true});',
        content
    )
    # Fix SignupModal definition
    content = re.sub(
        r'class SignupModal extends StatefulWidget \{\s*final void Function\(String\) onSignup;\s*const SignupModal\(\{super\.key, required this\.onSignup\}\);',
        r'class SignupModal extends StatefulWidget {\n  final void Function(String) onSignup;\n  final bool isTagalog;\n\n  const SignupModal({super.key, required this.onSignup, this.isTagalog = true});',
        content
    )

    # Login Modal titles and texts
    content = content.replace("'Mag-log in'", "widget.isTagalog ? 'Mag-log in' : 'Log In'")
    content = content.replace("'Welcome back to our community'", "widget.isTagalog ? 'Maligayang pagbabalik sa ating komunidad' : 'Welcome back to our community'")
    content = content.replace("'Welcome back to Sto. Rosario Parish Church'", "widget.isTagalog ? 'Maligayang pagbabalik sa Sto. Rosario Parish Church' : 'Welcome back to Sto. Rosario Parish Church'")

    # Signup Modal titles and texts
    content = content.replace("'Mag-sign up'", "widget.isTagalog ? 'Mag-sign up' : 'Sign Up'")
    content = content.replace("'Join our spiritual community'", "widget.isTagalog ? 'Sumali sa ating espirituwal na komunidad' : 'Join our spiritual community'")

    # Form field labels and placeholders
    content = content.replace("'Email Address'", "widget.isTagalog ? 'Email' : 'Email Address'")
    content = content.replace("'Enter your email'", "widget.isTagalog ? 'Ilagay ang iyong email' : 'Enter your email'")
    content = content.replace("'Password'", "widget.isTagalog ? 'Password' : 'Password'")
    content = content.replace("'Create a password'", "widget.isTagalog ? 'Gumawa ng password' : 'Create a password'")
    content = content.replace("'Confirm Password'", "widget.isTagalog ? 'Kumpirmahin ang Password' : 'Confirm Password'")
    content = content.replace("'Confirm your password'", "widget.isTagalog ? 'Kumpirmahin ang iyong password' : 'Confirm your password'")
    content = content.replace("'Full Name'", "widget.isTagalog ? 'Buong Pangalan' : 'Full Name'")
    content = content.replace("'Enter your full name'", "widget.isTagalog ? 'Ilagay ang iyong buong pangalan' : 'Enter your full name'")
    content = content.replace("'Forgot Password?'", "widget.isTagalog ? 'Nakalimutan ang Password?' : 'Forgot Password?'")

    # Terms checkbox
    content = content.replace("'I accept the Terms and Conditions'", "widget.isTagalog ? 'Tinatanggap ko ang mga Tuntunin at Kundisyon' : 'I accept the Terms and Conditions'")

    # Fix error messages in validation
    return content

with open('c:/src/parish_church/sto_rosario_parish_church/lib/parishioner_dashboard.dart', 'r', encoding='utf-8') as f:
    dash_content = f.read()

# Update usages inside _showAuthDialog and _showLoginModal / _showSignupModal
dash_content = dash_content.replace("return SignupModal(onSignup: _navigateToDashboardFromAuth);", "return SignupModal(onSignup: _navigateToDashboardFromAuth, isTagalog: _isLanguageTagalog);")
dash_content = dash_content.replace("return LoginModal(onLogin: _navigateToDashboardFromAuth);", "return LoginModal(onLogin: _navigateToDashboardFromAuth, isTagalog: _isLanguageTagalog);")

dash_content = dash_content.replace(
    "'Welcome to Sto. Rosario Parish Church'", 
    "_isLanguageTagalog ? 'Maligayang pagdating sa Sto. Rosario Parish Church' : 'Welcome to Sto. Rosario Parish Church'"
)

# _showAuthDialog has button texts without widget.isTagalog because it's in the state class, so we use _isLanguageTagalog there
dash_content = dash_content.replace(
    "child: const Text(\n                      'Mag-sign up'",
    "child: Text(\n                      _isLanguageTagalog ? 'Mag-sign up' : 'Sign Up'"
)
dash_content = dash_content.replace(
    "child: const Text(\n                      'Mag-log in'",
    "child: Text(\n                      _isLanguageTagalog ? 'Mag-log in' : 'Log In'"
)

dash_content = fix_modals(dash_content)

with open('c:/src/parish_church/sto_rosario_parish_church/lib/parishioner_dashboard.dart', 'w', encoding='utf-8') as f:
    f.write(dash_content)


with open('c:/src/parish_church/sto_rosario_parish_church/lib/features/auth/landing_page.dart', 'r', encoding='utf-8') as f:
    land_content = f.read()

# Add _isTagalog toggle to LandingPage
if "bool _isTagalog = true;" not in land_content:
    land_content = land_content.replace("class _LandingPageState extends State<LandingPage> {", "class _LandingPageState extends State<LandingPage> {\n  bool _isTagalog = true;")

land_content = land_content.replace("return SignupModal(onSignup: _navigateToDashboard);", "return SignupModal(onSignup: _navigateToDashboard, isTagalog: _isTagalog);")
land_content = land_content.replace("return LoginModal(onLogin: _navigateToDashboard);", "return LoginModal(onLogin: _navigateToDashboard, isTagalog: _isTagalog);")

land_content = land_content.replace(
    "'Log In'", 
    "_isTagalog ? 'Mag-log in' : 'Log In'"
)
land_content = land_content.replace(
    "'Sign Up'", 
    "_isTagalog ? 'Mag-sign up' : 'Sign Up'"
)
land_content = land_content.replace(
    "'Continue as Guest'", 
    "_isTagalog ? 'Magpatuloy bilang Bisita' : 'Continue as Guest'"
)
land_content = land_content.replace(
    "'Welcome to our spiritual community'", 
    "_isTagalog ? 'Maligayang pagdating sa ating espirituwal na komunidad' : 'Welcome to our spiritual community'"
)

# Replace const before these widgets if needed
land_content = land_content.replace("child: const Text(\n                              'Sign Up'", "child: Text(\n                              _isTagalog ? 'Mag-sign up' : 'Sign Up'")
land_content = land_content.replace("child: const Text(\n                              'Log In'", "child: Text(\n                              _isTagalog ? 'Mag-log in' : 'Log In'")

# Add language toggle to top right
toggle_code = '''
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
'''
if "Alignment.topRight" not in land_content:
    land_content = land_content.replace("SafeArea(\n            child: Column(", "SafeArea(\n            child: Stack(\n              children: [\n                Column(")
    land_content = land_content.replace("© 2026 Sto. Rosario Parish Church',\n                    style: TextStyle(color: ParishColors.blue200, fontSize: 12),\n                  ),\n                ),\n              ],", "© 2026 Sto. Rosario Parish Church',\n                    style: TextStyle(color: ParishColors.blue200, fontSize: 12),\n                  ),\n                ),\n              ],\n            ),\n" + toggle_code + "\n              ],")

land_content = fix_modals(land_content)

with open('c:/src/parish_church/sto_rosario_parish_church/lib/features/auth/landing_page.dart', 'w', encoding='utf-8') as f:
    f.write(land_content)
