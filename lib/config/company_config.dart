class CompanyConfig {
  // Default company ID - can be modified based on environment or user selection
  static const int defaultCompanyId = 5;
  
  // Method to get company ID (can be extended later for dynamic company selection)
  static int getCompanyId() {
    return defaultCompanyId;
  }
  
  // Optional: Add company-specific configurations
  static const Map<int, String> companyNames = {
    5: 'Default Company',
    // Add more companies as needed
  };
  
  // Get company name by ID
  static String getCompanyName(int companyId) {
    return companyNames[companyId] ?? 'Unknown Company';
  }
}