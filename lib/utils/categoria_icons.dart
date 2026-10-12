import 'package:flutter/material.dart';

class CategoriaIconOption {
  const CategoriaIconOption({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const categoriaIconOptions = <CategoriaIconOption>[
  CategoriaIconOption(
    id: 'home_repair',
    label: 'Servicos',
    icon: Icons.home_repair_service_outlined,
  ),
  CategoriaIconOption(
    id: 'electrical_services',
    label: 'Eletrica',
    icon: Icons.electrical_services_outlined,
  ),
  CategoriaIconOption(
    id: 'plumbing',
    label: 'Hidraulica',
    icon: Icons.plumbing_outlined,
  ),
  CategoriaIconOption(
    id: 'format_paint',
    label: 'Pintura',
    icon: Icons.format_paint_outlined,
  ),
  CategoriaIconOption(
    id: 'cleaning_services',
    label: 'Limpeza',
    icon: Icons.cleaning_services_outlined,
  ),
  CategoriaIconOption(id: 'build', label: 'Manutencao', icon: Icons.build),
  CategoriaIconOption(
    id: 'ac_unit',
    label: 'Ar-condicionado',
    icon: Icons.ac_unit_outlined,
  ),
  CategoriaIconOption(
    id: 'construction',
    label: 'Reformas',
    icon: Icons.construction_outlined,
  ),
  CategoriaIconOption(id: 'grass', label: 'Jardim', icon: Icons.grass_outlined),
  CategoriaIconOption(
    id: 'category',
    label: 'Outros',
    icon: Icons.category_outlined,
  ),
];

IconData categoriaIconData(String? id) {
  return categoriaIconOptions
      .firstWhere(
        (option) => option.id == id,
        orElse: () => categoriaIconOptions.first,
      )
      .icon;
}
