import 'package:flutter/material.dart';

class FilterSheetResult {
  final String sortBy;
  final String order;
  final String? priority;
  final String? dueDate;
  final String? category; // Added category field

  FilterSheetResult({
    required this.sortBy,
    required this.order,
    this.priority,
    this.dueDate,
    this.category, // Added to constructor
  });
}

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    required this.initialFilters,
    super.key,
  });

  final FilterSheetResult initialFilters;

  @override
  _FilterSheetState createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String _sortBy = 'date';
  String _order = 'ascending';
  String? _priority;
  String? _dueDate;
  String? _category; // Added category state

  @override
  void initState() {
    _sortBy = widget.initialFilters.sortBy;
    _order = widget.initialFilters.order;
    _priority = widget.initialFilters.priority;
    _dueDate = widget.initialFilters.dueDate;
    _category = widget.initialFilters.category; // Initialize from props
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Use dark theme colors
    final isDark = true;
    final textColor = isDark ? Colors.white : Colors.black;
    final backgroundColor = isDark ? Colors.grey[900] : Colors.white;
    final secondaryColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, left: 32, right: 32, bottom: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sort By and Order
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sort By', style: TextStyle(color: textColor)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _sortBy,
                              isExpanded: true,
                              dropdownColor: Colors.grey[850],
                              style: TextStyle(color: textColor),
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, color: textColor),
                              items: const [
                                DropdownMenuItem(value: 'date', child: Text('Creation Date')),
                                DropdownMenuItem(value: 'due', child: Text('Due Date')),
                                DropdownMenuItem(value: 'priority', child: Text('Priority')),
                                DropdownMenuItem(value: 'category', child: Text('Category')), // Added category option
                                DropdownMenuItem(value: 'completed', child: Text('Completion')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _sortBy = value ?? _sortBy;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order', style: TextStyle(color: textColor)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: secondaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _order,
                              isExpanded: true,
                              dropdownColor: Colors.grey[850],
                              style: TextStyle(color: textColor),
                              underline: const SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, color: textColor),
                              items: const [
                                DropdownMenuItem(value: 'ascending', child: Text('Ascending')),
                                DropdownMenuItem(value: 'descending', child: Text('Descending')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _order = value ?? _order;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Category Filter (new)
                Text('Category', style: TextStyle(color: textColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCategoryChip('Development', 'development', Colors.blue),
                    _buildCategoryChip('Debugging', 'debugging', Colors.purple),
                    _buildCategoryChip('Testing', 'testing', Colors.amber),
                    _buildCategoryChip('Deployment', 'deployment', Colors.teal),
                    _buildCategoryChip('Docs', 'docs', Colors.indigo),
                    _buildCategoryChip('Communication', 'communication', Colors.pink),
                  ],
                ),
                const SizedBox(height: 24),

                // Priority Filter
                Text('Priority', style: TextStyle(color: textColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPriorityChip('High', 'high', Colors.red),
                    _buildPriorityChip('Medium', 'medium', Colors.orange),
                    _buildPriorityChip('Low', 'low', Colors.green),
                  ],
                ),
                const SizedBox(height: 24),

                // Due Date Filter
                Text('Due Date', style: TextStyle(color: textColor)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDateChip('Overdue', 'overdue', Colors.red),
                    _buildDateChip('Today', 'today', Colors.blue),
                    _buildDateChip('Future', 'future', Colors.green),
                  ],
                ),
                const SizedBox(height: 24),

                // Active Filters Row
                if (_priority != null || _dueDate != null || _category != null) // Added category to condition
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Active Filters:', style: TextStyle(color: textColor)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_priority != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(_priority!).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _getPriorityColor(_priority!)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _priority!.substring(0, 1).toUpperCase() + _priority!.substring(1),
                                      style: TextStyle(color: textColor, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => setState(() => _priority = null),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            if (_dueDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getDateColor(_dueDate!).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _getDateColor(_dueDate!)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _dueDate!.substring(0, 1).toUpperCase() + _dueDate!.substring(1),
                                      style: TextStyle(color: textColor, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => setState(() => _dueDate = null),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            // Add category chip to active filters
                            if (_category != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(_category!).withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _getCategoryColor(_category!)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getCategoryDisplayText(_category!),
                                      style: TextStyle(color: textColor, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => setState(() => _category = null),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Apply and Reset Buttons
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _priority = null;
                            _dueDate = null;
                            _category = null; // Reset category filter
                            _sortBy = 'date';
                            _order = 'descending';
                          });
                        },
                        child: const Text('Reset Filters'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(
                            context,
                            FilterSheetResult(
                              sortBy: _sortBy,
                              order: _order,
                              priority: _priority,
                              dueDate: _dueDate,
                              category: _category, // Include category in result
                            ),
                          );
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build category chip filter
  Widget _buildCategoryChip(String label, String value, Color color) {
    final isSelected = _category == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: Colors.grey[800],
      selectedColor: color.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[400],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey[700]!,
        width: isSelected ? 2 : 1,
      ),
      onSelected: (_) {
        setState(() {
          _category = isSelected ? null : value;
        });
      },
    );
  }

  Widget _buildPriorityChip(String label, String value, Color color) {
    final isSelected = _priority == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: Colors.grey[800],
      selectedColor: color.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[400],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey[700]!,
        width: isSelected ? 2 : 1,
      ),
      onSelected: (_) {
        setState(() {
          _priority = isSelected ? null : value;
        });
      },
    );
  }

  Widget _buildDateChip(String label, String value, Color color) {
    final isSelected = _dueDate == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: Colors.grey[800],
      selectedColor: color.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[400],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey[700]!,
        width: isSelected ? 2 : 1,
      ),
      onSelected: (_) {
        setState(() {
          _dueDate = isSelected ? null : value;
        });
      },
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  Color _getDateColor(String dueDate) {
    switch (dueDate.toLowerCase()) {
      case 'overdue':
        return Colors.red;
      case 'today':
        return Colors.blue;
      case 'future':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  // Get color for category
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'development':
        return Colors.blue;
      case 'debugging':
        return Colors.purple;
      case 'testing':
        return Colors.amber;
      case 'deployment':
        return Colors.teal;
      case 'docs':
        return Colors.indigo;
      case 'communication':
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  // Get display text for category
  String _getCategoryDisplayText(String category) {
    final capitalize = category.substring(0, 1).toUpperCase() + category.substring(1);
    return capitalize;
  }
}