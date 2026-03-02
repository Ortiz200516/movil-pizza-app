import 'package:flutter/material.dart';
import '../services/usuarios_service.dart';
import '../models/usuario.dart';
import '../utils/paises.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final UsuariosService _usuariosService = UsuariosService();
  final TextEditingController _buscarController = TextEditingController();
  
  String _filtroRol = 'todos';
  String _textoBusqueda = '';

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 Gestión de Usuarios'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: TextField(
              controller: _buscarController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, email o cédula...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _textoBusqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _buscarController.clear();
                            _textoBusqueda = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _textoBusqueda = value.toLowerCase();
                });
              },
            ),
          ),

          // Filtros por rol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFiltroChip('Todos', 'todos', Icons.people),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Clientes', 'cliente', Icons.person),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Cocineros', 'cocinero', Icons.restaurant),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Repartidores', 'repartidor', Icons.delivery_dining),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Meseros', 'mesero', Icons.room_service),
                  const SizedBox(width: 8),
                  _buildFiltroChip('Admins', 'admin', Icons.admin_panel_settings),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Lista de usuarios
          Expanded(
            child: StreamBuilder<List<Usuario>>(
              stream: _usuariosService.obtenerTodosUsuarios(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay usuarios registrados',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Filtrar usuarios
                var usuarios = snapshot.data!;

                // Filtrar por rol
                if (_filtroRol != 'todos') {
                  usuarios = usuarios.where((u) => u.rol == _filtroRol).toList();
                }

                // Filtrar por búsqueda
                if (_textoBusqueda.isNotEmpty) {
                  usuarios = usuarios.where((u) {
                    final nombre = (u.nombre ?? '').toLowerCase();
                    final email = u.email.toLowerCase();
                    final cedula = (u.cedula ?? '').toLowerCase();
                    final pais = (u.pais ?? '').toLowerCase();

                    return nombre.contains(_textoBusqueda) ||
                        email.contains(_textoBusqueda) ||
                        cedula.contains(_textoBusqueda) ||
                        pais.contains(_textoBusqueda);
                  }).toList();
                }

                if (usuarios.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No se encontraron usuarios',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final usuario = usuarios[index];
                    return _buildUsuarioCard(usuario);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, String valor, IconData icono) {
    final isSelected = _filtroRol == valor;
    return FilterChip(
      avatar: Icon(icono, size: 18),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filtroRol = valor;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.purple.shade100,
      checkmarkColor: Colors.purple,
      side: BorderSide(
        color: isSelected ? Colors.purple : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildUsuarioCard(Usuario usuario) {
    // Color según rol
    Color colorRol;
    IconData iconoRol;

    switch (usuario.rol) {
      case 'admin':
        colorRol = Colors.purple;
        iconoRol = Icons.admin_panel_settings;
        break;
      case 'cocinero':
        colorRol = Colors.orange;
        iconoRol = Icons.restaurant;
        break;
      case 'repartidor':
        colorRol = Colors.teal;
        iconoRol = Icons.delivery_dining;
        break;
      case 'mesero':
        colorRol = Colors.blue;
        iconoRol = Icons.room_service;
        break;
      default:
        colorRol = Colors.grey;
        iconoRol = Icons.person;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorRol.withOpacity(0.2),
          child: Icon(iconoRol, color: colorRol),
        ),
        title: Text(
          usuario.nombre ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              usuario.email,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            
            // Mostrar país y cédula
            if (usuario.cedula != null && usuario.pais != null)
              Row(
                children: [
                  Text(
                    usuario.paisConBandera,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Cédula: ${usuario.cedula}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 6),
            
            // Badge del rol
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorRol.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                usuario.rol.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorRol,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información completa
                _buildInfoRow(Icons.person, 'Nombre', usuario.nombre ?? 'Sin nombre'),
                _buildInfoRow(Icons.email, 'Email', usuario.email),
                if (usuario.telefono != null)
                  _buildInfoRow(Icons.phone, 'Teléfono', usuario.telefono!),
                if (usuario.cedula != null && usuario.pais != null)
                  _buildInfoRow(
                    Icons.badge,
                    'Cédula',
                    '${usuario.paisConBandera} - ${usuario.cedula}',
                  ),

                const Divider(height: 24),

                const Text(
                  'Cambiar rol:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),

                // Botones para cambiar rol
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRolButton(usuario, 'cliente', 'Cliente', Icons.person, Colors.grey),
                    _buildRolButton(usuario, 'cocinero', 'Cocinero', Icons.restaurant, Colors.orange),
                    _buildRolButton(usuario, 'repartidor', 'Repartidor', Icons.delivery_dining, Colors.teal),
                    _buildRolButton(usuario, 'mesero', 'Mesero', Icons.room_service, Colors.blue),
                    _buildRolButton(usuario, 'admin', 'Admin', Icons.admin_panel_settings, Colors.purple),
                  ],
                ),

                // Estado de disponibilidad (solo para repartidores y meseros)
                if (usuario.rol == 'repartidor' || usuario.rol == 'mesero') ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Disponible:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Switch(
                        value: usuario.disponible ?? false,
                        onChanged: (value) async {
                          await _usuariosService.cambiarDisponibilidad(
                            usuario.uid,
                            value,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  value
                                      ? '✅ Usuario disponible'
                                      : '❌ Usuario no disponible',
                                ),
                              ),
                            );
                          }
                        },
                        activeThumbColor: Colors.green,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icono, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolButton(
    Usuario usuario,
    String rol,
    String label,
    IconData icono,
    Color color,
  ) {
    final isCurrentRol = usuario.rol == rol;

    return ElevatedButton.icon(
      onPressed: isCurrentRol
          ? null
          : () async {
              // Confirmar cambio
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('⚠️ Confirmar cambio de rol'),
                  content: Text(
                    '¿Cambiar a ${usuario.nombre ?? usuario.email} a rol de $label?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirmar'),
                    ),
                  ],
                ),
              );

              if (confirmar == true) {
                await _usuariosService.cambiarRol(usuario.uid, rol);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Rol cambiado a $label'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
      icon: Icon(icono, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrentRol ? color : Colors.white,
        foregroundColor: isCurrentRol ? Colors.white : color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}