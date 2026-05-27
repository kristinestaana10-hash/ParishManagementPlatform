const fs = require('fs');

function repairLandingPage(filePath) {
    let content = fs.readFileSync(filePath, 'utf8');

    // Mending the Action buttons section
    const actionButtonsReplacement = `
                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _showSignupModal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.primaryGold,
                              foregroundColor: ParishColors.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              elevation: 4,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                            child: Text(_isTagalog ? 'Mag-sign up' : 'Sign Up',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Log In Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _showLoginModal,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                            ),
                            child: Text(_isTagalog ? 'Mag-log in' : 'Log In',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Guest access
                        TextButton(
                          onPressed: () =>
                              _navigateToDashboard('Guest', isGuest: true),
                          child: Text(_isTagalog ? 'Magpatuloy bilang Bisita' : 'Continue as Guest',
                            style: TextStyle(
                              color: ParishColors.blue200,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),`;

    // Replace everything from `// Sign Up Button` to `// Footer`
    content = content.replace(/\/\/ Sign Up Button[\s\S]*?\/\/ Footer/g, actionButtonsReplacement + "\n                      ],\n                    ),\n                  ),\n                ),\n\n                // Footer");
    
    fs.writeFileSync(filePath, content, 'utf8');
}

function fixDashboardErrors(filePath) {
    let content = fs.readFileSync(filePath, 'utf8');

    // Error in parishioner_dashboard.dart: 
    // `_isLanguageTagalog ? 'Mag-sign up' : 'Sign Up' : 'Sign Up'`
    content = content.replace(/_isLanguageTagalog \? 'Mag-sign up' : 'Sign Up' : 'Sign Up'/g, "_isLanguageTagalog ? 'Mag-sign up' : 'Sign Up'");
    content = content.replace(/_isLanguageTagalog \? 'Mag-log in' : 'Log In' : 'Log In'/g, "_isLanguageTagalog ? 'Mag-log in' : 'Log In'");

    fs.writeFileSync(filePath, content, 'utf8');
}

repairLandingPage('c:/src/parish_church/sto_rosario_parish_church/lib/features/auth/landing_page.dart');
fixDashboardErrors('c:/src/parish_church/sto_rosario_parish_church/lib/parishioner_dashboard.dart');
