import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants.dart';
import '../../core/providers/events_provider.dart';
import '../../data/models/event.dart';

class EventsScreen extends StatefulWidget {
  @override
  _EventsScreenState createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showPastEvents = false;
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _eventTypes = [
    {'label': 'Научное', 'value': 'научное', 'icon': Icons.science},
    {'label': 'Культурное', 'value': 'культурное', 'icon': Icons.theater_comedy},
    {'label': 'Волонтерство', 'value': 'волонтерство', 'icon': Icons.volunteer_activism},
    {'label': 'Спортивное', 'value': 'спортивное', 'icon': Icons.sports},
    {'label': 'Образовательное', 'value': 'образовательное', 'icon': Icons.school},
    {'label': 'Развлекательное', 'value': 'развлекательное', 'icon': Icons.celebration},
  ];
  String _selectedType = 'научное';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EventsProvider>(context, listen: false).loadEvents();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showAddEventDialog() {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    final TextEditingController locationController = TextEditingController();
    final TextEditingController organizerController = TextEditingController();
    final TextEditingController pointsController = TextEditingController();

    _selectedDate = DateTime.now().add(Duration(days: 7));
    _selectedTime = TimeOfDay(hour: 10, minute: 0);

    _animationController.forward(from: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {},
            child: DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) => Container(
                decoration: BoxDecoration(
                  color: AppConstants.surfaceWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: Colors.grey[600]),
                            ),
                            Expanded(
                              child: Text(
                                'Добавить мероприятие',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: Icon(Icons.close, color: Colors.transparent),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            physics: BouncingScrollPhysics(),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildTextField(
                                    controller: titleController,
                                    label: 'Название мероприятия',
                                    icon: Icons.event,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Введите название';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    controller: descController,
                                    label: 'Описание',
                                    icon: Icons.description,
                                    maxLines: 3,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Введите описание';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16),

                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                                          child: Text(
                                            'Дата и время',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Material(
                                                color: AppConstants.surfaceWhite,
                                                borderRadius: BorderRadius.circular(12),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(12),
                                                  onTap: () async {
                                                    final date = await showDatePicker(
                                                      context: context,
                                                      initialDate: _selectedDate ?? DateTime.now(),
                                                      firstDate: DateTime.now(),
                                                      lastDate: DateTime(2030),
                                                      builder: (context, child) {
                                                        return Theme(
                                                          data: ThemeData.light().copyWith(
                                                            colorScheme: ColorScheme.light(
                                                              primary: Colors.black,
                                                              onPrimary: AppConstants.surfaceWhite,
                                                              surface: AppConstants.surfaceWhite,
                                                              onSurface: Colors.black,
                                                            ),
                                                            dialogBackgroundColor: AppConstants.surfaceWhite,
                                                          ),
                                                          child: child!,
                                                        );
                                                      },
                                                    );
                                                    if (date != null) {
                                                      setState(() {
                                                        _selectedDate = date;
                                                      });
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants.surfaceWhite,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.grey[300]!),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.calendar_today,
                                                            color: Colors.grey[600], size: 20),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            _selectedDate != null
                                                                ? DateFormat('dd.MM.yyyy').format(_selectedDate!)
                                                                : 'Выберите дату',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              color: _selectedDate != null
                                                                  ? Colors.black
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Material(
                                                color: AppConstants.surfaceWhite,
                                                borderRadius: BorderRadius.circular(12),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(12),
                                                  onTap: () async {
                                                    final time = await showTimePicker(
                                                      context: context,
                                                      initialTime: _selectedTime ?? TimeOfDay.now(),
                                                      builder: (context, child) {
                                                        return Theme(
                                                          data: ThemeData.light().copyWith(
                                                            colorScheme: ColorScheme.light(
                                                              primary: Colors.black,
                                                              onPrimary: AppConstants.surfaceWhite,
                                                              surface: AppConstants.surfaceWhite,
                                                              onSurface: Colors.black,
                                                            ),
                                                            dialogBackgroundColor: AppConstants.surfaceWhite,
                                                          ),
                                                          child: child!,
                                                        );
                                                      },
                                                    );
                                                    if (time != null) {
                                                      setState(() {
                                                        _selectedTime = time;
                                                      });
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: AppConstants.surfaceWhite,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.grey[300]!),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.access_time,
                                                            color: Colors.grey[600], size: 20),
                                                        SizedBox(width: 12),
                                                        Expanded(
                                                          child: Text(
                                                            _selectedTime != null
                                                                ? _selectedTime!.format(context)
                                                                : 'Выберите время',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              color: _selectedTime != null
                                                                  ? Colors.black
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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

                                  SizedBox(height: 16),
                                  _buildTextField(
                                    controller: locationController,
                                    label: 'Место проведения',
                                    icon: Icons.location_on,
                                  ),
                                  SizedBox(height: 16),
                                  _buildTextField(
                                    controller: organizerController,
                                    label: 'Организатор',
                                    icon: Icons.people,
                                  ),

                                  SizedBox(height: 16),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8, bottom: 4),
                                          child: Text(
                                            'Тип мероприятия',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppConstants.surfaceWhite,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey[300]!),
                                          ),
                                          child: DropdownButtonFormField<String>(
                                            value: _selectedType,
                                            decoration: InputDecoration.collapsed(hintText: ''),
                                            icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black,
                                            ),
                                            items: _eventTypes.map((type) {
                                              return DropdownMenuItem<String>(
                                                value: type['value'],
                                                child: Row(
                                                  children: [
                                                    Icon(type['icon'],
                                                        color: Colors.grey[600], size: 20),
                                                    SizedBox(width: 12),
                                                    Text(type['label']),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedType = value!;
                                              });
                                            },
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Выберите тип мероприятия';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 16),
                                  _buildTextField(
                                    controller: pointsController,
                                    label: 'Баллы за участие',
                                    icon: Icons.star,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Введите количество баллов';
                                      }
                                      if (int.tryParse(value) == null) {
                                        return 'Введите число';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),

                        Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF4CAF50).withOpacity(0.3),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                if (_formKey.currentState!.validate() &&
                                    _selectedDate != null && _selectedTime != null) {
                                  Navigator.pop(context);

                                  _animationController.reverse();
                                  await Future.delayed(Duration(milliseconds: 300));

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle, color: AppConstants.surfaceWhite),
                                          SizedBox(width: 8),
                                          Expanded(child: Text('Мероприятие успешно добавлено')),
                                        ],
                                      ),
                                      backgroundColor: Color(0xFF4CAF50),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Заполните все обязательные поля'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              child: Center(
                                child: AnimatedBuilder(
                                  animation: _animationController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: 1 - (_animationController.value * 0.1),
                                      child: child,
                                    );
                                  },
                                  child: Text(
                                    'ДОБАВИТЬ МЕРОПРИЯТИЕ',
                                    style: TextStyle(
                                      color: AppConstants.surfaceWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      _animationController.reverse();
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          filled: true,
          fillColor: AppConstants.surfaceWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 16 : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event, BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animationController.value * 10),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppConstants.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              _showEventDetails(event, context);
            },
            onLongPress: () {
              _showOptionsDialog(event, context);
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getTypeColor(event.type),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                event.type,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppConstants.surfaceWhite,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF000000), Color(0xFF0E0E0E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${event.points}',
                          style: TextStyle(
                            color: AppConstants.surfaceWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  Text(
                    event.description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 16),

                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    text: DateFormat('dd.MM.yyyy · HH:mm').format(event.date),
                  ),
                  _buildInfoRow(
                    icon: Icons.location_on,
                    text: event.location,
                  ),
                  _buildInfoRow(
                    icon: Icons.people,
                    text: event.organizer,
                  ),
                  SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(event).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(event).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(event),
                              color: _getStatusColor(event),
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              _getStatusText(event),
                              style: TextStyle(
                                color: _getStatusColor(event),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (event.attended && event.certificateUrl != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                              begin: Alignment.centerLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: AppConstants.surfaceWhite, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Сертификат',
                                style: TextStyle(
                                  color: AppConstants.surfaceWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'научное':
        return Color(0xFF2196F3);
      case 'культурное':
        return Color(0xFF9C27B0);
      case 'волонтерство':
        return Color(0xFF4CAF50);
      case 'спортивное':
        return Color(0xFFFF9800);
      case 'образовательное':
        return Color(0xFF009688);
      case 'развлекательное':
        return Color(0xFFE91E63);
      default:
        return Color(0xFF607D8B);
    }
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(Event event) {
    if (event.attended) return Color(0xFF4CAF50);
    if (event.date.isBefore(DateTime.now())) return Colors.grey;
    return Color(0xFF2196F3);
  }

  IconData _getStatusIcon(Event event) {
    if (event.attended) return Icons.check_circle;
    if (event.date.isBefore(DateTime.now())) return Icons.history;
    return Icons.upcoming;
  }

  String _getStatusText(Event event) {
    if (event.attended) return 'Посещено';
    if (event.date.isBefore(DateTime.now())) return 'Завершено';
    return 'Предстоящее';
  }

  void _showEventDetails(Event event, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {},
            child: DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              builder: (context, scrollController) => Container(
                decoration: BoxDecoration(
                  color: AppConstants.surfaceWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        physics: BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF000000), Color(0xFF0E0E0E)],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${event.points} баллов',
                                      style: TextStyle(
                                        color: AppConstants.surfaceWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getTypeColor(event.type),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  event.type,
                                  style: TextStyle(
                                    color: AppConstants.surfaceWhite,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                event.description,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                              SizedBox(height: 24),
                              _buildDetailCard(
                                icon: Icons.calendar_today,
                                title: 'Дата и время',
                                value: DateFormat('dd MMMM yyyy, HH:mm').format(event.date),
                              ),
                              _buildDetailCard(
                                icon: Icons.location_on,
                                title: 'Место проведения',
                                value: event.location,
                              ),
                              _buildDetailCard(
                                icon: Icons.people,
                                title: 'Организатор',
                                value: event.organizer,
                              ),
                              SizedBox(height: 20),
                              if (event.attended && event.certificateUrl != null) ...[
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF4CAF50).withOpacity(0.1),
                                        Color(0xFF2E7D32).withOpacity(0.1)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Color(0xFF4CAF50).withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        color: Color(0xFF4CAF50),
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Сертификат доступен',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            GestureDetector(
                                              onTap: () async {
                                                Navigator.pop(context);
                                                await _openCertificate(event.certificateUrl!);
                                              },
                                              child: Text(
                                                'Открыть сертификат',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),
                              ],
                              if (!event.attended && event.date.isAfter(DateTime.now()))
                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Provider.of<EventsProvider>(context, listen: false)
                                            .registerForEvent(event.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(Icons.check_circle, color: AppConstants.surfaceWhite),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text('Вы зарегистрированы на мероприятие'),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: Color(0xFF4CAF50),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Center(
                                        child: Text(
                                          'ЗАРЕГИСТРИРОВАТЬСЯ',
                                          style: TextStyle(
                                            color: AppConstants.surfaceWhite,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCertificate(String url) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.open_in_browser, color: AppConstants.surfaceWhite),
            SizedBox(width: 8),
            Text('Данная функция будет внедренна позже'),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog(Event event, BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppConstants.surfaceWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.edit,
              title: 'Редактировать',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showEditEventDialog(event);
              },
            ),
            _buildOptionTile(
              icon: Icons.delete,
              title: 'Удалить',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(event, context);
              },
            ),
            _buildOptionTile(
              icon: Icons.share,
              title: 'Поделиться',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _shareEvent(event);
              },
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text('Отмена'),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _showEditEventDialog(Event event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.edit, color: AppConstants.surfaceWhite),
            SizedBox(width: 8),
            Text('Редактирование мероприятия'),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _shareEvent(Event event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.share, color: AppConstants.surfaceWhite),
            SizedBox(width: 8),
            Text('Поделиться мероприятием'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showDeleteConfirmation(Event event, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Удалить мероприятие?'),
          ],
        ),
        content: Text('Вы уверены, что хотите удалить мероприятие "${event.title}"? Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.delete, color: AppConstants.surfaceWhite),
                      SizedBox(width: 8),
                      Text('Мероприятие удалено'),
                    ],
                  ),
                  backgroundColor: Colors.grey[800],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPDF(BuildContext context) async {
    final provider = Provider.of<EventsProvider>(context, listen: false);
    final attendedEvents = provider.pastEvents.where((e) => e.attended).toList();

    if (attendedEvents.isEmpty) {
      _showErrorDialog('Нет посещенных мероприятий для экспорта');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
            SizedBox(height: 20),
            Text(
              'Создание PDF...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Отчет о посещенных мероприятиях',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Студент: Виноградов Игорь',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Группа: 1521621 | ИПИТ',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Дата создания: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '${provider.pastEvents.where((e) => e.attended).fold<int>(0, (sum, e) => sum + e.points)}',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Всего баллов',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            '${attendedEvents.length}',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Посещено мероприятий',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              pw.Table.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey700,
                ),
                cellStyle: pw.TextStyle(fontSize: 10),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                },
                headers: ['Мероприятие', 'Дата', 'Баллы', 'Сертификат'],
                data: attendedEvents.map((event) => [
                  event.title,
                  DateFormat('dd.MM.yyyy').format(event.date),
                  '${event.points}',
                  event.certificateUrl ?? 'Не указан'
                ]).toList(),
              ),

              pw.SizedBox(height: 30),

              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: pw.EdgeInsets.only(top: 20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Генеральный секретарь',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Университетский комитет по мероприятиям',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ),
              ),
            ];
          },
        ),
      );

      final directory = await getDownloadsDirectory();
      final filePath = '${directory!.path}/Посещенные_мероприятия_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      Navigator.pop(context);

      _showSuccessDialog(context, filePath);

    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog('Ошибка при создании PDF: $e');
    }
  }

  void _showSuccessDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(
          Icons.check_circle,
          color: Color(0xFF4CAF50),
          size: 48,
        ),
        title: Text(
          'PDF успешно создан!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Файл сохранен в папку "Загрузки":\n\n${filePath.split('/').last}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Закрыть', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await OpenFile.open(filePath);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Открыть файл'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(
          Icons.error_outline,
          color: Colors.black,
          size: 48,
        ),
        title: Text('Ошибка'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EventsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Мероприятия',
        ),
        backgroundColor: AppConstants.surfaceWhite,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _exportToPDF(context),
            icon: Icon(Icons.picture_as_pdf),
            tooltip: 'Экспорт в PDF',
          ),
          IconButton(
            onPressed: () => provider.loadEvents(),
            icon: Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: Colors.black,
                            size: 28,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '${provider.pastEvents.where((e) => e.attended).fold<int>(0, (sum, e) => sum + e.points)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'набрано баллов',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: Colors.black,
                            size: 28,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '${provider.pastEvents.where((e) => e.attended).length}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'посещено',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Предстоящие',
                    style: TextStyle(
                      fontSize: 14,
                      color: !_showPastEvents ? Colors.black : Colors.grey,
                      fontWeight: !_showPastEvents ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Switch(
                    value: _showPastEvents,
                    onChanged: (value) {
                      setState(() {
                        _showPastEvents = value;
                      });
                    },
                    activeColor: Colors.black,
                    activeTrackColor: Colors.grey[300],
                  ),
                  Text(
                    'Прошедшие',
                    style: TextStyle(
                      fontSize: 14,
                      color: _showPastEvents ? Colors.black : Colors.grey,
                      fontWeight: _showPastEvents ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: provider.isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Загрузка мероприятий...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
                  : provider.error != null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.orange,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => provider.loadEvents(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: Text('Повторить'),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: () async {
                  await provider.loadEvents();
                },
                color: Colors.black,
                backgroundColor: AppConstants.surfaceWhite,
                child: ListView.builder(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 80),
                  itemCount: _showPastEvents
                      ? provider.pastEvents.length
                      : provider.upcomingEvents.length,
                  itemBuilder: (context, index) {
                    final events = _showPastEvents
                        ? provider.pastEvents
                        : provider.upcomingEvents;
                    return _buildEventCard(events[index], context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: AnimatedScale(
        scale: provider.isLoading ? 0 : 1,
        duration: Duration(milliseconds: 300),
        child: FloatingActionButton.extended(
          onPressed: _showAddEventDialog,
          backgroundColor: Colors.black,
          foregroundColor: AppConstants.surfaceWhite,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Icon(Icons.add),
          label: Text('Добавить'),
        ),
      ),
    );
  }
}