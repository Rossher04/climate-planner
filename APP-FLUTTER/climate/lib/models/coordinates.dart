class Coordinates {
  const Coordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

// Nombre de ubicacion -> id real en la base de datos de Django.
// Se usa para resolver el id de la ubicacion al crear/editar actividades.
final locationIds = <String, int>{};
