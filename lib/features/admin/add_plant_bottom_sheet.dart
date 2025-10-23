import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAddPlantBottomSheet extends StatefulWidget {
  const AdminAddPlantBottomSheet({super.key});

  @override
  State<AdminAddPlantBottomSheet> createState() =>
      _AdminAddPlantBottomSheetState();
}

class _AdminAddPlantBottomSheetState extends State<AdminAddPlantBottomSheet>
    with SingleTickerProviderStateMixin {
   int _selectedTab = 0; // 0 = Available, 1 = Add
   int _currentStep = 0;
   int _selectedParameter = 0; // 0: PH, 1: PPM, 2: Harvest
   int? _editingPlantId; // Track which plant is being edited
   String _selectedCategory = 'free'; // 'free', 'paid', 'package'
   bool _showPlantPhaseView = false; // Toggle between cover image view and plant phase view

   // Controllers
   final TextEditingController _plantNameController = TextEditingController();
   final TextEditingController _phMinController = TextEditingController();
   final TextEditingController _phMaxController = TextEditingController();
   final TextEditingController _ppmMinController = TextEditingController();
   final TextEditingController _ppmMaxController = TextEditingController();
   final TextEditingController _harvestController = TextEditingController();

   String? _uploadedImageUrl; // Cover image URL
   bool _isUploadingImage = false;

   // Plant phase images: 4 phases × 3 states (normal, dead, water)
   Map<String, String?> _plantPhaseImages = {
     'phase1_normal': null,
     'phase1_dead': null,
     'phase1_water': null,
     'phase2_normal': null,
     'phase2_dead': null,
     'phase2_water': null,
     'phase3_normal': null,
     'phase3_dead': null,
     'phase3_water': null,
     'phase4_normal': null,
     'phase4_dead': null,
     'phase4_water': null,
   };

   bool _isUploadingPhaseImage = false;
   String? _currentUploadingPhase;

   late final AnimationController _animCtrl =
       AnimationController(vsync: this, duration: const Duration(milliseconds: 150));

  final List<Map<String, String>> _steps = [
    {
      'title': 'Plant Name',
      'description': 'What is the name of your plant, seed, or vegetable?',
    },
    {
      'title': 'Upload Image',
      'description': 'Upload an image of your plant for easy identification.',
    },
    {
      'title': 'PH, PPM & Harvest',
      'description': 'Adjust PH range, PPM range, and days to harvest.',
    },
    {
      'title': 'Category',
      'description': 'Select the category for this plant template.',
    },
    {
      'title': 'Preview & Add',
      'description': 'Review your plant details and add it to your garden.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _harvestController.text = '30';
    _phMinController.text = '1.5';
    _phMaxController.text = '2.0';
    _ppmMinController.text = '100';
    _ppmMaxController.text = '200';
  }

  @override
  void dispose() {
    _plantNameController.dispose();
    _phMinController.dispose();
    _phMaxController.dispose();
    _ppmMinController.dispose();
    _ppmMaxController.dispose();
    _harvestController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // --- Helper methods ---

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

  // --- Helper increment/decrement methods ---

  void _adjustDouble(TextEditingController c, double step, bool inc) {
    double v = double.tryParse(c.text) ?? 0;
    v = inc ? v + step : (v - step);
    setState(() => c.text = v.toStringAsFixed(1));
  }

  void _adjustInt(TextEditingController c, int step, bool inc, {int min = 0}) {
    int v = int.tryParse(c.text) ?? min;
    v = inc ? v + step : (v - step);
    if (v < min) v = min;
    setState(() => c.text = v.toString());
  }

  // --------------------------
// Part 2: Step 3 UI
// --------------------------

  Widget _buildPHRangeSelector() {
    final screen = MediaQuery.of(context).size;
    final small = screen.width < 600;

    return Column(
      children: [
        Text(
          'PH Range',
          style: GoogleFonts.inter(
            fontSize: small ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: small ? 8 : 12),
        Row(
          children: [
            // Minimum PH
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Min PH',
                    style: GoogleFonts.inter(
                      fontSize: small ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: small ? 8 : 12),
                  Container(
                    height: small ? 140 : 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEC4899), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Up arrow
                        IconButton(
                          onPressed: () => _adjustDouble(_phMinController, 0.1, true),
                          icon: Icon(Icons.keyboard_arrow_up, color: const Color(0xFFEC4899), size: small ? 24 : 28),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        // Value with padding
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: small ? 6 : 8),
                          child: Text(
                            _phMinController.text,
                            style: GoogleFonts.inter(
                              fontSize: small ? 20 : 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEC4899),
                            ),
                          ),
                        ),
                        // Down arrow
                        IconButton(
                          onPressed: () => _adjustDouble(_phMinController, 0.1, false),
                          icon: Icon(Icons.keyboard_arrow_down, color: const Color(0xFFEC4899), size: small ? 24 : 28),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: small ? 12 : 16),
            // Maximum PH
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Max PH',
                    style: GoogleFonts.inter(
                      fontSize: small ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: small ? 8 : 12),
                  Container(
                    height: small ? 140 : 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEC4899), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Up arrow
                        IconButton(
                          onPressed: () => _adjustDouble(_phMaxController, 0.1, true),
                          icon: Icon(Icons.keyboard_arrow_up, color: const Color(0xFFEC4899), size: small ? 24 : 28),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        // Value with padding
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: small ? 6 : 8),
                          child: Text(
                            _phMaxController.text,
                            style: GoogleFonts.inter(
                              fontSize: small ? 20 : 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEC4899),
                            ),
                          ),
                        ),
                        // Down arrow
                        IconButton(
                          onPressed: () => _adjustDouble(_phMaxController, 0.1, false),
                          icon: Icon(Icons.keyboard_arrow_down, color: const Color(0xFFEC4899), size: small ? 24 : 28),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPPMRangeSelector() {
    final screen = MediaQuery.of(context).size;
    final small = screen.width < 600;

    return Column(
      children: [
        Text(
          'PPM Range',
          style: GoogleFonts.inter(
            fontSize: small ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: small ? 8 : 12),
        Row(
          children: [
            // Minimum PPM
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Min PPM',
                    style: GoogleFonts.inter(
                      fontSize: small ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: small ? 8 : 12),
                  Container(
                    height: small ? 140 : 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEAB308), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Up arrow
                        IconButton(
                          onPressed: () => _adjustInt(_ppmMinController, 10, true, min: 0),
                          icon: Icon(Icons.keyboard_arrow_up, color: const Color(0xFFEAB308), size: small ? 24 : 28),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        // Value with padding
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: small ? 6 : 8),
                          child: Text(
                            _ppmMinController.text,
                            style: GoogleFonts.inter(
                              fontSize: small ? 20 : 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEAB308),
                            ),
                          ),
                        ),
                        // Down arrow
                        IconButton(
                          onPressed: () => _adjustInt(_ppmMinController, 10, false, min: 0),
                          icon: Icon(Icons.keyboard_arrow_down, color: const Color(0xFFEAB308), size: small ? 24 : 28),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: small ? 12 : 16),
            // Maximum PPM
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Max PPM',
                    style: GoogleFonts.inter(
                      fontSize: small ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: small ? 8 : 12),
                  Container(
                    height: small ? 140 : 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEAB308), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Up arrow
                        IconButton(
                          onPressed: () => _adjustInt(_ppmMaxController, 10, true, min: 0),
                          icon: Icon(Icons.keyboard_arrow_up, color: const Color(0xFFEAB308), size: small ? 24 : 28),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        // Value with padding
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: small ? 6 : 8),
                          child: Text(
                            _ppmMaxController.text,
                            style: GoogleFonts.inter(
                              fontSize: small ? 20 : 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEAB308),
                            ),
                          ),
                        ),
                        // Down arrow
                        IconButton(
                          onPressed: () => _adjustInt(_ppmMaxController, 10, false, min: 0),
                          icon: Icon(Icons.keyboard_arrow_down, color: const Color(0xFFEAB308), size: small ? 24 : 28),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

// --------------------------
// Part 2: Step 3 UI
// --------------------------

  Widget _buildTimeSelector({
    required String label,
    required String value,
    required VoidCallback onIncrement,
    required VoidCallback? onDecrement,
    required Color color,
  }) {
    final screen = MediaQuery.of(context).size;
    final small = screen.width < 600;

    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: small ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: small ? 8 : 12),
        Container(
          height: small ? 140 : 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Up arrow
              IconButton(
                onPressed: onIncrement,
                icon: Icon(Icons.keyboard_arrow_up, color: color, size: small ? 24 : 28),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              // Value with padding
              Padding(
                padding: EdgeInsets.symmetric(vertical: small ? 6 : 8),
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: small ? 20 : 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              // Down arrow
              IconButton(
                onPressed: onDecrement,
                icon: Icon(Icons.keyboard_arrow_down, color: color, size: small ? 24 : 28),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildStep3Interactive() {
    final screen = MediaQuery.of(context).size;
    final small = screen.width < 600;
    final contentPadding = small ? 16.0 : 20.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(contentPadding),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Tab buttons for PH, PPM, Harvest - adapted from reference design
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedParameter = 0),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: small ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedParameter == 0
                          ? const Color(0xFFEC4899) // Pink for PH
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEC4899),
                        width: _selectedParameter == 0 ? 0 : 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'PH',
                        style: GoogleFonts.inter(
                          fontSize: small ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: _selectedParameter == 0
                              ? Colors.white
                              : const Color(0xFFEC4899),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: small ? 8 : 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedParameter = 1),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: small ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedParameter == 1
                          ? const Color(0xFFEAB308) // Yellow for PPM
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEAB308),
                        width: _selectedParameter == 1 ? 0 : 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'PPM',
                        style: GoogleFonts.inter(
                          fontSize: small ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: _selectedParameter == 1
                              ? Colors.white
                              : const Color(0xFFEAB308),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: small ? 8 : 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedParameter = 2),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: small ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedParameter == 2
                          ? const Color(0xFF4ADE80) // Green for Harvest
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF4ADE80),
                        width: _selectedParameter == 2 ? 0 : 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Harvest',
                        style: GoogleFonts.inter(
                          fontSize: small ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: _selectedParameter == 2
                              ? Colors.white
                              : const Color(0xFF4ADE80),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: small ? 16 : 20),
          // Content based on selected parameter - using reference design style
          Container(
            padding: EdgeInsets.all(small ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: _selectedParameter == 0
                ? _buildPHRangeSelector()
                : _selectedParameter == 1
                    ? _buildPPMRangeSelector()
                    : _buildTimeSelector(
                        label: 'Days to Harvest',
                        value: _harvestController.text,
                        onIncrement: () => _adjustInt(_harvestController, 1, true, min: 1),
                        onDecrement: () => _adjustInt(_harvestController, 1, false, min: 1),
                        color: const Color(0xFF4ADE80),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    final screen = MediaQuery.of(context).size;
    final small = screen.width < 600;
    final contentPadding = small ? 16.0 : 20.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(contentPadding),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            'Select Category',
            style: GoogleFonts.inter(
              fontSize: small ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: small ? 16 : 20),
          Row(
            children: [
              // Free Category
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = 'free'),
                  child: Container(
                    height: small ? 100 : 120, // Fixed height for rectangular shape
                    margin: EdgeInsets.all(small ? 4 : 6),
                    decoration: BoxDecoration(
                      color: _selectedCategory == 'free' ? const Color(0xFF4ADE80) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4ADE80),
                        width: _selectedCategory == 'free' ? 0 : 3,
                      ),
                      boxShadow: _selectedCategory == 'free'
                          ? [
                              BoxShadow(
                                color: const Color(0xFF4ADE80).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.eco,
                          size: small ? 32 : 40,
                          color: _selectedCategory == 'free' ? Colors.white : const Color(0xFF4ADE80),
                        ),
                        SizedBox(height: small ? 8 : 12),
                        Text(
                          'Free',
                          style: GoogleFonts.inter(
                            fontSize: small ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedCategory == 'free' ? Colors.white : const Color(0xFF4ADE80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Paid Category
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = 'paid'),
                  child: Container(
                    height: small ? 100 : 120, // Fixed height for rectangular shape
                    margin: EdgeInsets.all(small ? 4 : 6),
                    decoration: BoxDecoration(
                      color: _selectedCategory == 'paid' ? const Color(0xFF8B5CF6) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6),
                        width: _selectedCategory == 'paid' ? 0 : 3,
                      ),
                      boxShadow: _selectedCategory == 'paid'
                          ? [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star,
                          size: small ? 32 : 40,
                          color: _selectedCategory == 'paid' ? Colors.white : const Color(0xFF8B5CF6),
                        ),
                        SizedBox(height: small ? 8 : 12),
                        Text(
                          'Paid',
                          style: GoogleFonts.inter(
                            fontSize: small ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedCategory == 'paid' ? Colors.white : const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Package Category
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = 'package'),
                  child: Container(
                    height: small ? 100 : 120, // Fixed height for rectangular shape
                    margin: EdgeInsets.all(small ? 4 : 6),
                    decoration: BoxDecoration(
                      color: _selectedCategory == 'package' ? const Color(0xFFF97316) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF97316),
                        width: _selectedCategory == 'package' ? 0 : 3,
                      ),
                      boxShadow: _selectedCategory == 'package'
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF97316).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: small ? 32 : 40,
                          color: _selectedCategory == 'package' ? Colors.white : const Color(0xFFF97316),
                        ),
                        SizedBox(height: small ? 8 : 12),
                        Text(
                          'Package',
                          style: GoogleFonts.inter(
                            fontSize: small ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedCategory == 'package' ? Colors.white : const Color(0xFFF97316),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: small ? 16 : 20),
          Container(
            padding: EdgeInsets.all(small ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              _selectedCategory == 'free'
                  ? 'Free plants are available to all users without any cost or restrictions.'
                  : _selectedCategory == 'paid'
                      ? 'Paid plants require purchase or subscription to access and use.'
                      : 'Package plants are part of bundled offerings with multiple plants included.',
              style: GoogleFonts.inter(
                fontSize: small ? 12 : 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  // --------------------------
  // Part 3: rest of file
  // --------------------------

  Future<List<Map<String, dynamic>>> _fetchAvailablePlants() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('add_plant')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _deletePlant(int plantId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('add_plant').delete().eq('id', plantId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plant deleted successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

      // Refresh the plant list
      setState(() {});
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete plant: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editPlant(Map<String, dynamic> plant) async {
    // Store the plant ID for editing
    _editingPlantId = plant['id'];

    // Pre-populate controllers with existing plant data
    _plantNameController.text = plant['name'] ?? '';
    _phMinController.text = plant['ph_min']?.toString() ?? '';
    _phMaxController.text = plant['ph_max']?.toString() ?? '';
    _ppmMinController.text = plant['ppm_min']?.toString() ?? '';
    _ppmMaxController.text = plant['ppm_max']?.toString() ?? '';
    _harvestController.text = plant['days_to_harvest']?.toString() ?? '';
    _uploadedImageUrl = plant['image_url'];
    _selectedCategory = plant['category'] ?? 'free';

    // Pre-populate plant phase images
    _plantPhaseImages = {
      'phase1_normal': plant['phase1_normal_image'],
      'phase1_dead': plant['phase1_dead_image'],
      'phase1_water': plant['phase1_water_image'],
      'phase2_normal': plant['phase2_normal_image'],
      'phase2_dead': plant['phase2_dead_image'],
      'phase2_water': plant['phase2_water_image'],
      'phase3_normal': plant['phase3_normal_image'],
      'phase3_dead': plant['phase3_dead_image'],
      'phase3_water': plant['phase3_water_image'],
      'phase4_normal': plant['phase4_normal_image'],
      'phase4_dead': plant['phase4_dead_image'],
      'phase4_water': plant['phase4_water_image'],
    };

    // Reset to first step for editing
    setState(() => _currentStep = 0);

    // Switch to add plant tab
    setState(() => _selectedTab = 1);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit mode activated. Modify the plant details and save.'),
        backgroundColor: Color(0xFF3B82F6),
      ),
    );
  }

  Widget _buildPlantListItem(Map<String, dynamic> plant) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getCategoryColor(plant['category'] ?? 'free'),
            width: 2,
          ),
        ),
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
                      color: _getCategoryColor(plant['category'] ?? 'free'),
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
            // 3-dot menu button
            PopupMenuButton<String>(
              onSelected: (value) async {
                // Handle menu selection
                switch (value) {
                  case 'edit':
                    await _editPlant(plant);
                    break;
                  case 'delete':
                    // Show confirmation dialog
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Plant'),
                        content: Text('Are you sure you want to delete "${plant['name'] ?? 'this plant'}"? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await _deletePlant(plant['id']);
                    }
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final supabase = Supabase.instance.client;

    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to upload an image.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (imageFile == null) {
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      final imageBytes = await imageFile.readAsBytes();
      final fileExt = path.extension(imageFile.name);
      final fileName =
          '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}$fileExt';

      await supabase.storage.from('plant_images').uploadBinary(
            fileName,
            imageBytes,
            fileOptions:
                FileOptions(contentType: 'image/${fileExt.substring(1)}'),
          );

      final imageUrl =
          Supabase.instance.client.storage.from('plant_images').getPublicUrl(fileName);

      setState(() {
        _uploadedImageUrl = imageUrl;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cover image uploaded successfully!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } on StorageException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload cover image: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _pickAndUploadPhaseImage(String phaseKey) async {
    final supabase = Supabase.instance.client;

    if (supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to upload an image.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (imageFile == null) {
      return;
    }

    setState(() {
      _isUploadingPhaseImage = true;
      _currentUploadingPhase = phaseKey;
    });

    try {
      final imageBytes = await imageFile.readAsBytes();
      final fileExt = path.extension(imageFile.name);
      final fileName =
          '${supabase.auth.currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}_${phaseKey}$fileExt';

      await supabase.storage.from('plant_images').uploadBinary(
            fileName,
            imageBytes,
            fileOptions:
                FileOptions(contentType: 'image/${fileExt.substring(1)}'),
          );

      final imageUrl =
          Supabase.instance.client.storage.from('plant_images').getPublicUrl(fileName);

      setState(() {
        _plantPhaseImages[phaseKey] = imageUrl;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${phaseKey.replaceAll('_', ' ').toUpperCase()} image uploaded successfully!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } on StorageException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload ${phaseKey.replaceAll('_', ' ')} image: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhaseImage = false;
          _currentUploadingPhase = null;
        });
      }
    }
  }

  Future<void> _savePlant({int? editPlantId}) async {
    // Basic validation
    if (_plantNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a plant name'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (_uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload a plant image'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Parse harvest
    int daysToHarvest;
    try {
      daysToHarvest = int.parse(_harvestController.text.trim());
      if (daysToHarvest <= 0) throw FormatException('days must be > 0');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid harvest days (integer > 0)'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Parse PH (nullable)
    double? phMin;
    double? phMax;
    try {
      final minText = _phMinController.text.trim();
      final maxText = _phMaxController.text.trim();
      if (minText.isNotEmpty) phMin = double.parse(minText);
      if (maxText.isNotEmpty) phMax = double.parse(maxText);
      if (phMin != null && phMax != null && phMin > phMax) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PH minimum cannot be greater than PH maximum'),
              backgroundColor: Colors.red),
        );
        return;
      }
      // Optional: enforce PH bounds 0.0 - 14.0
      if ((phMin != null && (phMin < 0 || phMin > 14)) ||
          (phMax != null && (phMax < 0 || phMax > 14))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PH values must be between 0.0 and 14.0'),
              backgroundColor: Colors.red),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter valid PH numbers (e.g. 1.5)'),
            backgroundColor: Colors.red),
      );
      return;
    }

    // Parse PPM (nullable)
    int? ppmMin;
    int? ppmMax;
    try {
      final minText = _ppmMinController.text.trim();
      final maxText = _ppmMaxController.text.trim();
      if (minText.isNotEmpty) ppmMin = int.parse(minText);
      if (maxText.isNotEmpty) ppmMax = int.parse(maxText);
      if (ppmMin != null && ppmMax != null && ppmMin > ppmMax) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PPM minimum cannot be greater than PPM maximum'),
              backgroundColor: Colors.red),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter valid PPM integers (e.g. 100)'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final plantData = {
        'name': _plantNameController.text.trim(),
        'image_url': _uploadedImageUrl,
        'days_to_harvest': daysToHarvest,
        'ph_min': phMin,
        'ph_max': phMax,
        'ppm_min': ppmMin,
        'ppm_max': ppmMax,
        'category': _selectedCategory,
        // Plant phase images
        'phase1_normal_image': _plantPhaseImages['phase1_normal'],
        'phase1_dead_image': _plantPhaseImages['phase1_dead'],
        'phase1_water_image': _plantPhaseImages['phase1_water'],
        'phase2_normal_image': _plantPhaseImages['phase2_normal'],
        'phase2_dead_image': _plantPhaseImages['phase2_dead'],
        'phase2_water_image': _plantPhaseImages['phase2_water'],
        'phase3_normal_image': _plantPhaseImages['phase3_normal'],
        'phase3_dead_image': _plantPhaseImages['phase3_dead'],
        'phase3_water_image': _plantPhaseImages['phase3_water'],
        'phase4_normal_image': _plantPhaseImages['phase4_normal'],
        'phase4_dead_image': _plantPhaseImages['phase4_dead'],
        'phase4_water_image': _plantPhaseImages['phase4_water'],
      };

      if (editPlantId != null) {
        // Update existing plant
        await supabase.from('add_plant').update(plantData).eq('id', editPlantId);
      } else {
        // Insert new plant
        await supabase.from('add_plant').insert(plantData);
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editPlantId != null ? 'Plant updated successfully!' : 'Plant template created successfully!'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );

      // Clear form and reset edit state
      _clearForm();
      _editingPlantId = null;

      // Switch back to available plants tab to show changes
      setState(() => _selectedTab = 0);
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save plant: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearForm() {
    _plantNameController.clear();
    _phMinController.clear();
    _phMaxController.clear();
    _ppmMinController.clear();
    _ppmMaxController.clear();
    _harvestController.text = '30';
    _uploadedImageUrl = null;
    _currentStep = 0;
    _editingPlantId = null;
    _selectedCategory = 'free';
    _showPlantPhaseView = false;

    // Clear all plant phase images
    _plantPhaseImages = {
      'phase1_normal': null,
      'phase1_dead': null,
      'phase1_water': null,
      'phase2_normal': null,
      'phase2_dead': null,
      'phase2_water': null,
      'phase3_normal': null,
      'phase3_dead': null,
      'phase3_water': null,
      'phase4_normal': null,
      'phase4_dead': null,
      'phase4_water': null,
    };
  }

  Widget _buildCoverImageView(bool isSmallScreen) {
    return Column(
      key: const ValueKey('coverImageView'),
      children: [
        // Cover Image Section
        Text(
          'Cover Image',
          style: GoogleFonts.inter(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickAndUploadImage,
          child: Container(
            width: isSmallScreen ? 100 : 120,
            height: isSmallScreen ? 100 : 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _editingPlantId != null
                    ? const Color(0xFF3B82F6) // Blue for edit mode
                    : const Color(0xFFDC2626), // Red for add mode
                width: 2,
              ),
            ),
            child: _isUploadingImage
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                    ),
                  )
                : _uploadedImageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _uploadedImageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder:
                              (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFDC2626)),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error,
                                  size: isSmallScreen ? 32 : 40,
                                  color: Colors.red[400],
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                Text(
                                  'Failed to load',
                                  style: GoogleFonts.inter(
                                    color: Colors.red[400],
                                    fontWeight: FontWeight.w500,
                                    fontSize: isSmallScreen ? 10 : 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: isSmallScreen ? 32 : 40,
                            color: const Color(0xFFDC2626),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            'Cover Image',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Text(
          _uploadedImageUrl != null
              ? 'Cover image uploaded successfully! Tap to change.'
              : 'Upload a cover image for your plant display.',
          style: GoogleFonts.inter(
            fontSize: isSmallScreen ? 12 : 14,
            color: _uploadedImageUrl != null
                ? const Color(0xff757575)
                : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isSmallScreen ? 20 : 24),

        // Plant Phase Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showPlantPhaseView = true),
            icon: const Icon(Icons.photo_library),
            label: Text(
              'Manage Plant Phases',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ADE80),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 12 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlantPhaseUploadView(bool isSmallScreen) {
    return Column(
      key: const ValueKey('plantPhaseView'),
      children: [
        // Phase content - no header, just scrollable content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Phase 1
                _buildPhaseSection(1, isSmallScreen),
                SizedBox(height: isSmallScreen ? 20 : 24),

                // Phase 2
                _buildPhaseSection(2, isSmallScreen),
                SizedBox(height: isSmallScreen ? 20 : 24),

                // Phase 3
                _buildPhaseSection(3, isSmallScreen),
                SizedBox(height: isSmallScreen ? 20 : 24),

                // Phase 4
                _buildPhaseSection(4, isSmallScreen),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseSection(int phaseNumber, bool small) {
    String getOrdinalSuffix(int number) {
      if (number == 1) return '1st';
      if (number == 2) return '2nd';
      if (number == 3) return '3rd';
      return '${number}th';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${getOrdinalSuffix(phaseNumber)} Plant Phase',
          style: GoogleFonts.inter(
            fontSize: small ? 16 : 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: small ? 12 : 16),
        Row(
          children: [
            // Normal
            Expanded(
              child: _buildPhaseImagePlaceholder(
                'Normal',
                'phase${phaseNumber}_normal',
                const Color(0xFF4ADE80),
                small,
              ),
            ),
            SizedBox(width: small ? 8 : 12),
            // Dead
            Expanded(
              child: _buildPhaseImagePlaceholder(
                'Dead',
                'phase${phaseNumber}_dead',
                const Color(0xFFDC2626),
                small,
              ),
            ),
            SizedBox(width: small ? 8 : 12),
            // Water
            Expanded(
              child: _buildPhaseImagePlaceholder(
                'Water',
                'phase${phaseNumber}_water',
                const Color(0xFF3B82F6),
                small,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhaseImagePlaceholder(String label, String phaseKey, Color color, bool small) {
    final hasImage = _plantPhaseImages[phaseKey] != null;
    final isUploading = _isUploadingPhaseImage && _currentUploadingPhase == phaseKey;

    return GestureDetector(
      onTap: isUploading ? null : () => _pickAndUploadPhaseImage(phaseKey),
      child: Container(
        height: small ? 80 : 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage ? color : Colors.grey[300]!,
            width: hasImage ? 2 : 1,
          ),
        ),
        child: isUploading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _plantPhaseImages[phaseKey]!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red[400], size: small ? 20 : 24),
                          SizedBox(height: small ? 4 : 6),
                          Text(
                            'Error',
                            style: GoogleFonts.inter(
                              color: Colors.red[400],
                              fontSize: small ? 10 : 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        color: color,
                        size: small ? 24 : 28,
                      ),
                      SizedBox(height: small ? 4 : 6),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          color: color,
                          fontSize: small ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPreview() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    String phPreview() {
      final min = _phMinController.text.trim();
      final max = _phMaxController.text.trim();
      if (min.isEmpty && max.isEmpty) return 'N/A';
      if (min.isNotEmpty && max.isNotEmpty) return '$min - $max';
      if (min.isNotEmpty) return '≥ $min';
      return '≤ $max';
    }

    String ppmPreview() {
      final min = _ppmMinController.text.trim();
      final max = _ppmMaxController.text.trim();
      if (min.isEmpty && max.isEmpty) return 'N/A';
      if (min.isNotEmpty && max.isNotEmpty) return '$min - $max';
      if (min.isNotEmpty) return '≥ $min';
      return '≤ $max';
    }

    final harvest = _harvestController.text.trim().isNotEmpty
        ? _harvestController.text.trim()
        : 'N/A';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview',
            style: GoogleFonts.inter(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: isSmallScreen ? 40 : 48,
                      height: isSmallScreen ? 40 : 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getCategoryColor(_selectedCategory),
                          width: 2,
                        ),
                        image: DecorationImage(
                          image: _uploadedImageUrl != null
                              ? NetworkImage(_uploadedImageUrl!)
                              : const AssetImage('assets/images/placeholder.png')
                                  as ImageProvider,
                          fit: BoxFit.cover,
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
                          color: _getCategoryColor(_selectedCategory),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: Text(
                          _selectedCategory.toUpperCase(),
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
                SizedBox(width: isSmallScreen ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _plantNameController.text.isNotEmpty
                            ? _plantNameController.text
                            : 'Plant Name',
                        style: GoogleFonts.inter(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Wrap(
                        spacing: isSmallScreen ? 12 : 16,
                        runSpacing: 4,
                        children: [
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
                                phPreview(),
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
                                ppmPreview(),
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
                                Icons.grass,
                                size: isSmallScreen ? 14 : 16,
                                color: const Color(0xFF4ADE80), // Green for Harvest
                              ),
                              SizedBox(width: isSmallScreen ? 3 : 4),
                              Text(
                                '$harvest days',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final contentPadding = isSmallScreen ? 16.0 : 20.0;

    switch (_currentStep) {
      case 0: // Plant Name
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(contentPadding),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: _plantNameController,
            decoration: InputDecoration(
              labelText: 'Enter plant name',
              hintText: 'e.g. Lettuce, Pechay',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 12 : 16,
              ),
            ),
            style: GoogleFonts.inter(fontSize: isSmallScreen ? 14 : 16),
          ),
        );

      case 1: // Upload Images (Cover & Plant Phases)
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(contentPadding),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: _showPlantPhaseView ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            child: _showPlantPhaseView
                ? _buildPlantPhaseUploadView(isSmallScreen)
                : _buildCoverImageView(isSmallScreen),
          ),
        );

      case 2:
        return _buildStep3Interactive();

      case 3:
        return _buildCategorySelection();

      case 4:
        return _buildPreview();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProgressStepItem({
    required int stepNumber,
    required bool isActive,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted
              ? (_editingPlantId != null ? const Color(0xFF3B82F6) : const Color(0xFFDC2626))
              : isActive
                  ? (_editingPlantId != null ? const Color(0xFF3B82F6) : const Color(0xFFDC2626))
                  : Colors.grey[200],
          border: Border.all(
            color: isCompleted
                ? (_editingPlantId != null ? const Color(0xFF3B82F6) : const Color(0xFFDC2626))
                : isActive
                    ? (_editingPlantId != null ? const Color(0xFF3B82F6) : const Color(0xFFDC2626))
                    : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            stepNumber.toString(),
            style: GoogleFonts.inter(
              color: isCompleted || isActive ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailablePlantsContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAvailablePlants(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error fetching plants: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        final plants = snapshot.data;
        if (plants == null || plants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.eco, size: 64, color: Color(0xFFDC2626)),
                const SizedBox(height: 16),
                Text(
                  'No Plants Found',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a new plant using the \'+\' button!',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFDC2626).withAlpha(178),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Group plants by category
        final freePlants = plants.where((plant) => plant['category'] == 'free').toList();
        final paidPlants = plants.where((plant) => plant['category'] == 'paid').toList();
        final packagePlants = plants.where((plant) => plant['category'] == 'package').toList();

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
      },
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
        ...plants.map((plant) => _buildPlantListItem(plant)),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'free':
        return Icons.eco;
      case 'paid':
        return Icons.star;
      case 'package':
        return Icons.inventory_2;
      default:
        return Icons.eco;
    }
  }

  Widget _buildAddPlantsContent() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 16.0 : 20.0;
    final stepperWidth = isSmallScreen ? 50.0 : 60.0;

    return Column(
      children: [
        // Main content area
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(horizontalPadding),
            child: Row(
              children: [
                // Progress steps (left side)
                SizedBox(
                  width: stepperWidth,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableHeight = constraints.maxHeight;
                      final totalSteps = _steps.length;
                      final stepSpacing = availableHeight / totalSteps;

                      return Stack(
                        children: [
                          // Connecting lines
                          ...List.generate(
                            totalSteps - 1,
                            (index) {
                              final circleCenter1 =
                                  (stepSpacing * index) + (stepSpacing / 2);
                              final circleCenter2 =
                                  (stepSpacing * (index + 1)) +
                                      (stepSpacing / 2);
                              final lineTop = circleCenter1 + 20;
                              final lineBottom = circleCenter2 - 20;
                              final lineHeight = lineBottom - lineTop;

                              return Positioned(
                                top: lineTop,
                                left: stepperWidth / 2 - 1,
                                child: Container(
                                  width: 2,
                                  height: lineHeight,
                                  color: index < _currentStep
                                      ? (_editingPlantId != null ? const Color(0xFF3B82F6) : const Color(0xFFDC2626))
                                      : (_editingPlantId != null ? const Color(0xFF3B82F6) : const Color(0xFFDC2626))
                                          .withAlpha(76),
                                ),
                              );
                            },
                          ),
                          // Step circles
                          ...List.generate(
                            totalSteps,
                            (index) {
                              final topPosition =
                                  (stepSpacing * index) + (stepSpacing / 2) - 20;

                              return Positioned(
                                top: topPosition,
                                left: 0,
                                right: 0,
                                child: _buildProgressStepItem(
                                  stepNumber: index + 1,
                                  isActive: index == _currentStep,
                                  isCompleted: index < _currentStep,
                                  onTap: () {
                                    setState(() => _currentStep = index);
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 20),
                // Content (right side)
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[_currentStep]['title']!,
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        Text(
                          _steps[_currentStep]['description']!,
                          style: GoogleFonts.inter(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 24 : 32),
                        // Step-specific content
                        _buildStepContent(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Fixed navigation buttons at bottom
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Previous button (show in Step 2 when in plant phase view, or in other steps)
              if ((_currentStep == 1 && _showPlantPhaseView) ||
                  ((_editingPlantId != null && _currentStep > 0) || (_editingPlantId == null && _currentStep > 0)))
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_currentStep == 1 && _showPlantPhaseView) {
                        // In plant phase view: go back to cover image
                        setState(() => _showPlantPhaseView = false);
                      } else {
                        // Normal previous step navigation
                        setState(() => _currentStep--);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _editingPlantId != null
                            ? const Color(0xFF3B82F6) // Blue for edit mode
                            : const Color(0xFFDC2626), // Red for add mode
                        width: 2,
                      ),
                      foregroundColor: _editingPlantId != null
                          ? const Color(0xFF3B82F6) // Blue for edit mode
                          : const Color(0xFFDC2626), // Red for add mode
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 24,
                          vertical: isSmallScreen ? 10 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Previous',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ),
                ),
              if ((_currentStep == 1 && _showPlantPhaseView) ||
                  ((_editingPlantId != null && _currentStep > 0) || (_editingPlantId == null && _currentStep > 0)))
                SizedBox(width: isSmallScreen ? 12 : 16),

              // Cancel button (only visible when in plant phase view in Step 2)
              if (_currentStep == 1 && _showPlantPhaseView)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showPlantPhaseView = false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF6B7280),
                        width: 2,
                      ),
                      foregroundColor: const Color(0xFF6B7280),
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 24,
                          vertical: isSmallScreen ? 10 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ),
                ),
              if (_currentStep == 1 && _showPlantPhaseView) SizedBox(width: isSmallScreen ? 12 : 16),

              // Cancel/Close button (only in edit mode for other steps)
              if (_editingPlantId != null && _currentStep != 1)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cancel Edit'),
                          content: const Text('Are you sure you want to cancel editing? Any unsaved changes will be lost.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Continue Editing'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        _clearForm();
                        setState(() => _selectedTab = 0);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Edit cancelled.'),
                            backgroundColor: Color(0xFF6B7280),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF6B7280),
                        width: 2,
                      ),
                      foregroundColor: const Color(0xFF6B7280),
                      padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 24,
                          vertical: isSmallScreen ? 10 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ),
                ),
              if (_editingPlantId != null && _currentStep != 1) SizedBox(width: isSmallScreen ? 12 : 16),

              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (_currentStep < _steps.length - 1) {
                      setState(() => _currentStep++);
                    } else {
                      await _savePlant(editPlantId: _editingPlantId);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _editingPlantId != null
                        ? const Color(0xFF3B82F6) // Blue for edit mode
                        : const Color(0xFFDC2626), // Red for add mode
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 16 : 24,
                        vertical: isSmallScreen ? 10 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    _currentStep == _steps.length - 1
                        ? (_editingPlantId != null ? 'Apply' : 'Add Plant')
                        : 'Next',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: _selectedTab == 0
                            ? const LinearGradient(
                                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: _selectedTab == 0 ? null : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: _selectedTab == 0
                            ? null
                            : Border.all(
                                color: const Color(0xFFDC2626), width: 2),
                        boxShadow: _selectedTab == 0
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFDC2626).withAlpha(76),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.grey.withAlpha(25),
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
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Add/Edit plants tab (circular icon button)
                GestureDetector(
                  onTap: () => setState(() => _selectedTab = 1),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: _selectedTab == 1
                          ? (_editingPlantId != null
                              ? const LinearGradient(
                                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ))
                          : null,
                      color: _selectedTab == 1 ? null : Colors.white,
                      shape: BoxShape.circle,
                      border: _selectedTab == 1
                          ? null
                          : Border.all(
                              color: _editingPlantId != null
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFDC2626),
                              width: 2),
                      boxShadow: _selectedTab == 1
                          ? [
                              BoxShadow(
                                color: (_editingPlantId != null
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFDC2626))
                                    .withAlpha(76),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.grey.withAlpha(25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Icon(
                      _editingPlantId != null ? Icons.edit : Icons.add,
                      color: _selectedTab == 1
                          ? Colors.white
                          : (_editingPlantId != null
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFDC2626)),
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
}
