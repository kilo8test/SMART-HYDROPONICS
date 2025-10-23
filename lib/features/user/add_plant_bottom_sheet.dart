import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

class AddPlantBottomSheet extends StatefulWidget {
   const AddPlantBottomSheet({super.key});

   @override
   State<AddPlantBottomSheet> createState() => _AddPlantBottomSheetState();
}

class _AddPlantBottomSheetState extends State<AddPlantBottomSheet> {
    int _selectedTab = 0; // 0 for Available plants, 1 for Add plants
    List<Map<String, dynamic>> _userPlants = []; // User's added plants
    bool _isLoadingUserPlants = true;
    List<Map<String, dynamic>> _availablePlants = []; // All available plants
    bool _isLoadingAvailablePlants = false;
    bool _isRefreshing = false; // General refresh loading state

   @override
   void initState() {
     super.initState();
     _loadUserPlants();
     _loadAvailablePlants();
   }
 
   Future<void> _loadUserPlants() async {
     final user = AuthService.getCurrentUser();
     if (user == null) return;
 
     try {
       final supabase = Supabase.instance.client;
       final response = await supabase
           .from('user_plants')
           .select('plant_id, added_at, add_plant(*)')
           .eq('user_id', user.id);
 
       final userPlantsData = List<Map<String, dynamic>>.from(response);
       setState(() {
         _userPlants = userPlantsData.map((item) => item['add_plant'] as Map<String, dynamic>).toList();
         _isLoadingUserPlants = false;
       });
     } catch (e) {
       print('Error loading user plants: $e');
       setState(() {
         _isLoadingUserPlants = false;
       });
     }
   }
 
   Future<void> _loadAvailablePlants() async {
     setState(() {
       _isLoadingAvailablePlants = true;
     });
 
     try {
       final supabase = Supabase.instance.client;
       final response = await supabase
           .from('add_plant')
           .select()
           .order('created_at', ascending: false);
 
       setState(() {
         _availablePlants = List<Map<String, dynamic>>.from(response);
         _isLoadingAvailablePlants = false;
       });
     } catch (e) {
       print('Error loading available plants: $e');
       setState(() {
         _isLoadingAvailablePlants = false;
       });
     }
   }
 
   Future<void> _refreshData() async {
     setState(() {
       _isRefreshing = true;
     });
 
     try {
       await Future.wait([
         _loadUserPlants(),
         _loadAvailablePlants(),
       ]);
     } finally {
       if (mounted) {
         setState(() {
           _isRefreshing = false;
         });
       }
     }
   }
 
   @override
   Widget build(BuildContext context) {
     final screenSize = MediaQuery.of(context).size;
     final isSmallScreen = screenSize.width < 600;
     final bottomSheetHeight = screenSize.height * (isSmallScreen ? 0.9 : 0.85);
 
     return Container(
       height: bottomSheetHeight,
       constraints: BoxConstraints(
         maxHeight: screenSize.height * 0.95,
         minHeight: screenSize.height * 0.7,
       ),
       decoration: const BoxDecoration(
         color: Colors.white,
         borderRadius: BorderRadius.only(
           topLeft: Radius.circular(40),
           topRight: Radius.circular(40),
         ),
       ),
       child: Column(
         children: [
           // Handle bar
           Container(
             margin: const EdgeInsets.only(top: 10),
             width: 40,
             height: 4,
             decoration: BoxDecoration(
               color: Colors.grey[300],
               borderRadius: BorderRadius.circular(2),
             ),
           ),
           const SizedBox(height: 20),
           // Tab buttons
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 20),
             child: Row(
               children: [
                 // Available plants tab
                 Expanded(
                   child: GestureDetector(
                     onTap: () {
                       setState(() => _selectedTab = 0);
                       _refreshData(); // Refresh data when switching to available plants tab
                     },
                     child: Container(
                       padding: const EdgeInsets.symmetric(vertical: 12),
                       decoration: BoxDecoration(
                         color: _selectedTab == 0
                             ? const Color(0xFF4ADE80)
                             : Colors.white,
                         borderRadius: BorderRadius.circular(20),
                         border: _selectedTab == 0
                             ? null
                             : Border.all(
                                 color: const Color(0xFF4ADE80), width: 2),
                         boxShadow: _selectedTab == 0
                             ? [
                                 BoxShadow(
                                   color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                                   blurRadius: 8,
                                   offset: const Offset(0, 4),
                                 ),
                               ]
                             : [
                                 BoxShadow(
                                   color: Colors.grey.withValues(alpha: 0.1),
                                   blurRadius: 4,
                                   offset: const Offset(0, 2),
                                 ),
                               ],
                       ),
                       child: Center(
                         child: Text(
                           'Available plants',
                           style: GoogleFonts.inter(
                             fontSize: 16,
                             fontWeight: FontWeight.w600,
                             color: _selectedTab == 0
                                 ? Colors.white
                                 : const Color(0xFF4ADE80),
                           ),
                         ),
                       ),
                     ),
                   ),
                 ),
                 const SizedBox(width: 10),
                 // Add plants tab (circular icon button)
                 GestureDetector(
                   onTap: () {
                     setState(() => _selectedTab = 1);
                     _refreshData(); // Refresh data when switching to add plants tab
                   },
                   child: Container(
                     width: 50,
                     height: 50,
                     decoration: BoxDecoration(
                       color: _selectedTab == 1
                           ? const Color(0xFF4ADE80)
                           : Colors.white,
                       shape: BoxShape.circle,
                       border: _selectedTab == 1
                           ? null
                           : Border.all(
                               color: const Color(0xFF4ADE80), width: 2),
                       boxShadow: _selectedTab == 1
                           ? [
                               BoxShadow(
                                 color:
                                     const Color(0xFF4ADE80).withValues(alpha: 0.3),
                                 blurRadius: 8,
                                 offset: const Offset(0, 4),
                               ),
                             ]
                           : [
                               BoxShadow(
                                 color: Colors.grey.withValues(alpha: 0.1),
                                 blurRadius: 4,
                                 offset: const Offset(0, 2),
                               ),
                             ],
                     ),
                     child: Icon(
                       Icons.add,
                       color: _selectedTab == 1
                           ? Colors.white
                           : const Color(0xFF4ADE80),
                       size: 24,
                     ),
                   ),
                 ),
               ],
             ),
           ),
           const SizedBox(height: 20),
           // Content based on selected tab
           Expanded(
             child: _selectedTab == 0
                 ? _buildAvailablePlantsContent()
                 : _buildAddPlantsContent(),
           ),
         ],
       ),
     );
   }

  Widget _buildAvailablePlantsContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF4ADE80),
      child: _isLoadingUserPlants || _isRefreshing
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
              ),
            )
          : _buildAvailablePlantsList(),
    );
  }

  Widget _buildAvailablePlantsList() {

    if (_userPlants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 64, color: Color(0xFF4ADE80)),
            const SizedBox(height: 16),
            Text(
              'Available Plants',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4ADE80),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your garden plants will appear here once you add them.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF4ADE80).withAlpha(178),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group plants by category (same as admin)
    final freePlants = _userPlants.where((plant) => plant['category'] == 'free').toList();
    final paidPlants = _userPlants.where((plant) => plant['category'] == 'paid').toList();
    final packagePlants = _userPlants.where((plant) => plant['category'] == 'package').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        // Free Plants Section
        if (freePlants.isNotEmpty) ...[
          _buildCategorySection('Free Plants', freePlants, const Color(0xFF4ADE80)),
          const SizedBox(height: 20),
        ],
        // Paid Plants Section
        if (paidPlants.isNotEmpty) ...[
          _buildCategorySection('Paid Plants', paidPlants, const Color(0xFF8B5CF6)),
          const SizedBox(height: 20),
        ],
        // Package Plants Section
        if (packagePlants.isNotEmpty) ...[
          _buildCategorySection('Package Plants', packagePlants, const Color(0xFFF97316)),
        ],
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAvailablePlants() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('add_plant')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }


  Widget _buildPlantSelectionItem(Map<String, dynamic> plant) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final categoryColor = _getCategoryColor(plant['category'] ?? 'free');
    final isPlantAdded = _userPlants.any((p) => p['id'] == plant['id']);

    String phDisplay() {
      final phMin = plant['ph_min'];
      final phMax = plant['ph_max'];
      if (phMin == null && phMax == null) return 'N/A';
      if (phMin != null && phMax != null) return '${phMin.toString()} - ${phMax.toString()}';
      if (phMin != null) return '≥ ${phMin.toString()}';
      return '≤ ${phMax.toString()}';
    }

    String ppmDisplay() {
      final ppmMin = plant['ppm_min'];
      final ppmMax = plant['ppm_max'];
      if (ppmMin == null && ppmMax == null) return 'N/A';
      if (ppmMin != null && ppmMax != null) return '${ppmMin.toString()} - ${ppmMax.toString()}';
      if (ppmMin != null) return '≥ ${ppmMin.toString()}';
      return '≤ ${ppmMax.toString()}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.grey.withAlpha(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: categoryColor,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () async {
          if (isPlantAdded) {
            // Plant already added - show different feedback
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${plant['name'] ?? 'Plant'} is already in your garden!'),
                  backgroundColor: const Color(0xFF3B82F6),
                ),
              );
            }
            return;
          }

          // Show confirmation dialog
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add Plant to Garden'),
              content: Text(
                'Are you sure you want to add "${plant['name'] ?? 'this plant'}" to your garden?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: categoryColor,
                  ),
                  child: const Text('Add Plant'),
                ),
              ],
            ),
          );

          if (confirmed == true && mounted) {
            final user = AuthService.getCurrentUser();
            if (user == null) return;

            try {
              // Add plant to database
              final supabase = Supabase.instance.client;
              await supabase.from('user_plants').insert({
                'user_id': user.id,
                'plant_id': plant['id'],
              });

              // Refresh data to sync with database
              await _refreshData();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${plant['name'] ?? 'Plant'} added to your garden!'),
                  backgroundColor: const Color(0xFF16A34A),
                ),
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to add plant: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Plant Image with Category Label
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      plant['image_url'] ?? '',
                      width: isSmallScreen ? 60 : 70,
                      height: isSmallScreen ? 60 : 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: isSmallScreen ? 60 : 70,
                        height: isSmallScreen ? 60 : 70,
                        color: Colors.grey[200],
                        child: const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 4 : 6,
                        vertical: isSmallScreen ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        (plant['category'] ?? 'free').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 8 : 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Plant Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant['name'] ?? 'No Name',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: isSmallScreen ? 12 : 16,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.grass,
                              size: isSmallScreen ? 14 : 16,
                              color: const Color(0xFF4ADE80),
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 4),
                            Text(
                              '${plant['days_to_harvest'] ?? 'N/A'} days',
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.science,
                              size: isSmallScreen ? 14 : 16,
                              color: const Color(0xFFEC4899), // Pink for PH
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 4),
                            Text(
                              phDisplay(),
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.layers,
                              size: isSmallScreen ? 14 : 16,
                              color: const Color(0xFFEAB308), // Yellow for PPM
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 4),
                            Text(
                              ppmDisplay(),
                              style: GoogleFonts.inter(
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action button - Add or Arrow Right
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPlantAdded
                      ? categoryColor.withAlpha(51) // Lighter for added plants
                      : categoryColor.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlantAdded ? Icons.arrow_forward : Icons.add,
                  color: categoryColor,
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(String title, List<Map<String, dynamic>> plants, Color color) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 4 : 8,
            vertical: isSmallScreen ? 6 : 8,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 12,
                  vertical: isSmallScreen ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 10,
                  vertical: isSmallScreen ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${plants.length}',
                  style: GoogleFonts.inter(
                    fontSize: isSmallScreen ? 11 : 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...plants.map((plant) => _buildPlantSelectionItem(plant)),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'free':
        return const Color(0xFF4ADE80); // Green
      case 'paid':
        return const Color(0xFF8B5CF6); // Purple
      case 'package':
        return const Color(0xFFF97316); // Orange
      default:
        return const Color(0xFF4ADE80); // Default to green
    }
  }

  Widget _buildAddPlantsContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: const Color(0xFF4ADE80),
      child: _isLoadingAvailablePlants || _isRefreshing
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
              ),
            )
          : _buildAvailablePlantsGrid(),
    );
  }

  Widget _buildAvailablePlantsGrid() {
    if (_availablePlants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 64, color: Color(0xFF4ADE80)),
            const SizedBox(height: 16),
            Text(
              'No Plants Available',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4ADE80),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Admin has not added any plants yet.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF4ADE80).withAlpha(178),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group plants by category (same as admin)
    final freePlants = _availablePlants.where((plant) => plant['category'] == 'free').toList();
    final paidPlants = _availablePlants.where((plant) => plant['category'] == 'paid').toList();
    final packagePlants = _availablePlants.where((plant) => plant['category'] == 'package').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        // Free Plants Section
        if (freePlants.isNotEmpty) ...[
          _buildCategorySection('Free Plants', freePlants, const Color(0xFF4ADE80)),
          const SizedBox(height: 20),
        ],
        // Paid Plants Section
        if (paidPlants.isNotEmpty) ...[
          _buildCategorySection('Paid Plants', paidPlants, const Color(0xFF8B5CF6)),
          const SizedBox(height: 20),
        ],
        // Package Plants Section
        if (packagePlants.isNotEmpty) ...[
          _buildCategorySection('Package Plants', packagePlants, const Color(0xFFF97316)),
        ],
      ],
    );
  }

}