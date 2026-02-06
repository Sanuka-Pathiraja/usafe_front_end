import 'package:flutter/material.dart';
import 'config.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access data from Config
    final contacts = MockDatabase.trustedContacts;

    return Scaffold(
      backgroundColor: Colors.transparent, // Lets the Home radial gradient show through
      body: Column(
        children: [
          // 1. HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Trusted Contacts",
                  style: TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.white,
                    letterSpacing: 0.5
                  ),
                ),
                // Glassy Add Button
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                    onPressed: () {
                      // Add contact logic here
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. CONTACT LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return _buildContactCard(contact);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Map<String, String> contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9), // Slate card
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder), // Subtle border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          // TOP ROW: Avatar & Details
          Row(
            children: [
              // Avatar with glowing border
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.bgDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3), 
                    width: 1.5
                  ),
                  boxShadow: [
                     BoxShadow(
                       color: AppColors.primary.withOpacity(0.1), 
                       blurRadius: 12
                     )
                  ]
                ),
                child: Center(
                  child: Text(
                    contact['name']![0],
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.primary
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Name & Relation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact['name']!,
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_rounded, 
                          size: 14, 
                          color: AppColors.success.withOpacity(0.8)
                        ),
                        const SizedBox(width: 6),
                        Text(
                          contact['relation']!,
                          style: const TextStyle(
                            fontSize: 14, 
                            color: AppColors.textSub,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Menu Options
              IconButton(
                icon: Icon(Icons.more_horiz_rounded, color: AppColors.textSub.withOpacity(0.5)),
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(height: 20),
          
          // Divider Line
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          
          const SizedBox(height: 20),

          // BOTTOM ROW: Action Buttons
          Row(
            children: [
              // Call Button (Ghost Style)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.call, size: 20),
                  label: const Text("Call"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Alert Button (Solid Alert Color)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.emergency_share, size: 20, color: Colors.white),
                  label: const Text("Alert"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.alert,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 8,
                    shadowColor: AppColors.alert.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}