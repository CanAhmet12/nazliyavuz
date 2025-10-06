import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final bool isActive;
  final int sortOrder;
  final int? parentId;
  final List<Category>? children;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.isActive = true,
    this.sortOrder = 0,
    this.parentId,
    this.children,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
      parentId: json['parent_id'],
      children: json['children'] != null
          ? (json['children'] as List)
              .map((child) => Category.fromJson(child))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'is_active': isActive,
      'sort_order': sortOrder,
      'parent_id': parentId,
      'children': children?.map((child) => child.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        description,
        icon,
        isActive,
        sortOrder,
        parentId,
        children,
      ];
}
