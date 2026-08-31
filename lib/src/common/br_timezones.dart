/// Fusos IANA do Brasil, para o seletor da família.
const List<({String id, String label})> brTimezones = [
  (id: 'America/Sao_Paulo', label: 'Brasília (São Paulo)'),
  (id: 'America/Bahia', label: 'Bahia (Salvador)'),
  (id: 'America/Fortaleza', label: 'Ceará (Fortaleza)'),
  (id: 'America/Recife', label: 'Pernambuco (Recife)'),
  (id: 'America/Belem', label: 'Pará (Belém)'),
  (id: 'America/Manaus', label: 'Amazonas (Manaus)'),
  (id: 'America/Cuiaba', label: 'Mato Grosso (Cuiabá)'),
  (id: 'America/Campo_Grande', label: 'Mato Grosso do Sul (Campo Grande)'),
  (id: 'America/Rio_Branco', label: 'Acre (Rio Branco)'),
  (id: 'America/Noronha', label: 'Fernando de Noronha'),
];

const String defaultTimezone = 'America/Sao_Paulo';

String timezoneLabel(String id) {
  for (final tz in brTimezones) {
    if (tz.id == id) return tz.label;
  }
  return id;
}
