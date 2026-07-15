import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/teacher_service.dart';

class AddStudentScreen extends StatefulWidget {
  final List<dynamic> classAssignments;

  const AddStudentScreen({super.key, required this.classAssignments});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teacherService = TeacherService();

  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentMobileController = TextEditingController();
  final _guardianMobileController = TextEditingController();
  final _pickupPointController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedClassSection;
  bool _isLoading = false;
  List<dynamic> _vansList = [];
  String? _selectedVanId;
  Uint8List? _photoBytes;
  String? _photoBase64;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 50,
                  maxWidth: 800,
                );
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 50,
                  maxWidth: 800,
                );
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Set default to first assignment if available
    if (widget.classAssignments.isNotEmpty) {
      final first = widget.classAssignments[0];
      _selectedClassSection = '${first['className']}-${first['section']}';
    }
    _loadVans();
  }

  Future<void> _loadVans() async {
    final result = await _teacherService.getVans();
    if (result['success']) {
      setState(() {
        _vansList = result['data'] ?? [];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _parentNameController.dispose();
    _parentMobileController.dispose();
    _guardianMobileController.dispose();
    _pickupPointController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClassSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class and section'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Parse class and section from combined value
    final parts = _selectedClassSection!.split('-');
    final className = parts[0];
    final section = parts.length > 1 ? parts[1] : 'A';

    final result = await _teacherService.addStudent(
      name: _nameController.text.trim(),
      className: className,
      section: section,
      studentId: _studentIdController.text.trim(),
      email: _emailController.text.trim(),
      mobileNo: _mobileController.text.trim(),
      parentName: _parentNameController.text.trim(),
      parentMobile: _parentMobileController.text.trim(),
      guardianMobile: _guardianMobileController.text.trim(),
      vanId: _selectedVanId,
      pickupPoint: _pickupPointController.text.trim(),
      address: _addressController.text.trim(),
      photo: _photoBase64,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Student',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _showParentLoginDialog(),
            icon: const Icon(Icons.key, color: Color(0xFF6B4EFF)),
            label: const Text(
              'Create Parent Login',
              style: TextStyle(
                color: Color(0xFF6B4EFF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info Section
              _buildSectionHeader('Basic Information'),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _nameController,
                label: 'Student Name *',
                icon: Icons.person,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _studentIdController,
                label: 'Student ID',
                icon: Icons.numbers,
              ),
              const SizedBox(height: 12),

              // Class-Section dropdown (only shows assigned classes)
              widget.classAssignments.isEmpty
                  ? Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Class *',
                                labelStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              value: _selectedClassSection?.split('-')[0],
                              items: List.generate(12, (i) => '${i + 1}')
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text('Class $c'),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                final section = _selectedClassSection?.contains('-') == true
                                    ? _selectedClassSection!.split('-')[1]
                                    : 'A';
                                setState(() => _selectedClassSection = '$v-$section');
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Section *',
                                labelStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              value: _selectedClassSection?.contains('-') == true
                                  ? _selectedClassSection!.split('-')[1]
                                  : null,
                              items: ['A', 'B', 'C', 'D']
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text('Section $s'),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                final cls = _selectedClassSection?.contains('-') == true
                                    ? _selectedClassSection!.split('-')[0]
                                    : '1';
                                setState(() => _selectedClassSection = '$cls-$v');
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedClassSection,
                        decoration: const InputDecoration(
                          labelText: 'Class & Section *',
                          labelStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        items: widget.classAssignments.map<DropdownMenuItem<String>>((ca) {
                          final label = '${ca['className']}-${ca['section']}';
                          return DropdownMenuItem(
                            value: label,
                            child: Text('Class ${ca['className']} - Section ${ca['section']}'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedClassSection = v),
                      ),
                    ),

              const SizedBox(height: 24),
              _buildSectionHeader('Contact Information'),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _mobileController,
                label: 'Mobile No',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on,
                maxLines: 2,
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Parent Information'),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _parentNameController,
                label: 'Parent Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _parentMobileController,
                label: 'Parent Mobile',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _guardianMobileController,
                label: 'Guardian Mobile',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Transport Information'),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedVanId,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Bus/Van',
                    labelStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Van Assigned'),
                    ),
                    ..._vansList.map((van) {
                      return DropdownMenuItem<String>(
                        value: van['_id'],
                        child: Text('${van['vehicleNumber']} (${van['driverName']})'),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedVanId = v),
                ),
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _pickupPointController,
                label: 'Pickup Point',
                icon: Icons.location_history,
              ),

              const SizedBox(height: 24),
              _buildSectionHeader('Student Photo'),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _photoBytes == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: Colors.grey[400], size: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap to upload',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          )
                        : Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(
                                    _photoBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _photoBytes = null;
                                      _photoBase64 = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit and Cancel Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6B4EFF), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B4EFF),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B4EFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'ADD STUDENT',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B4EFF), width: 2),
        ),
      ),
    );
  }

  void _showParentLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => const ParentLoginGeneratorDialog(),
    );
  }
}

// Parent Login Generator Dialog
class ParentLoginGeneratorDialog extends StatefulWidget {
  const ParentLoginGeneratorDialog({super.key});

  @override
  State<ParentLoginGeneratorDialog> createState() =>
      _ParentLoginGeneratorDialogState();
}

class _ParentLoginGeneratorDialogState
    extends State<ParentLoginGeneratorDialog> {
  final _teacherService = TeacherService();
  List<dynamic> _students = [];
  String? _selectedStudentId;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _generatedUsername;
  String? _generatedPassword;
  bool _hasExistingLogin = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final result = await _teacherService.getStudents();
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _students = result['data'] ?? [];
      }
    });
  }

  Future<void> _generateLogin() async {
    if (_selectedStudentId == null) return;

    setState(() => _isGenerating = true);

    final result = await _teacherService.generateParentLogin(
      _selectedStudentId!,
    );

    setState(() {
      _isGenerating = false;
      if (result['success']) {
        _generatedUsername = result['data']['parentUsername'];
        _generatedPassword = result['data']['parentPassword'];
        _hasExistingLogin = result['data']['existing'] ?? false;
      }
    });

    if (!result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Parent Login',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              const Text(
                'Select Student',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStudentId,
                  decoration: const InputDecoration(border: InputBorder.none),
                  hint: const Text('Choose a student'),
                  items: _students.map<DropdownMenuItem<String>>((s) {
                    final hasLogin =
                        s['parentUsername'] != null &&
                        s['parentUsername'] != '';
                    return DropdownMenuItem(
                      value: s['_id'],
                      child: Row(
                        children: [
                          Text(s['name'] ?? ''),
                          if (hasLogin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Has Login',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedStudentId = v;
                      _generatedUsername = null;
                      _generatedPassword = null;

                      // Check if student already has login
                      final student = _students.firstWhere(
                        (s) => s['_id'] == v,
                        orElse: () => null,
                      );
                      if (student != null &&
                          student['parentUsername'] != null &&
                          student['parentUsername'] != '') {
                        _generatedUsername = student['parentUsername'];
                        _generatedPassword =
                            student['parentPassword'] ?? '(hidden)';
                        _hasExistingLogin = true;
                      } else {
                        _hasExistingLogin = false;
                      }
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              if (_generatedUsername != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasExistingLogin
                        ? const Color(0xFFFFF3CD)
                        : const Color(0xFFD4EDDA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasExistingLogin
                          ? const Color(0xFFFFEEBA)
                          : const Color(0xFFC3E6CB),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasExistingLogin
                            ? 'Existing Login Credentials'
                            : 'Generated Login Credentials',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _hasExistingLogin
                              ? const Color(0xFF856404)
                              : const Color(0xFF155724),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildCredentialRow('Username', _generatedUsername!),
                      const SizedBox(height: 8),
                      _buildCredentialRow('Password', _generatedPassword!),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      _selectedStudentId == null ||
                          _isGenerating ||
                          _hasExistingLogin
                      ? null
                      : _generateLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4EFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _hasExistingLogin
                              ? 'Already Has Login'
                              : 'GENERATE LOGIN',
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
