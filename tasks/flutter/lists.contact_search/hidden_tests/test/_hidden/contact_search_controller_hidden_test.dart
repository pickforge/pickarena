import 'package:flutter_test/flutter_test.dart';
import 'package:lists_contact_search/contact_search_controller.dart';

void main() {
  const contacts = [
    Contact(name: 'Charlie Rivers', email: 'charlie@example.com'),
    Contact(name: 'Alice Lee', email: 'alice@example.com'),
    Contact(name: 'Bob Stone', email: 'support+bob@example.com'),
    Contact(name: 'Alicia Keys', email: 'keys@example.org'),
  ];

  test('matches names case-insensitively after trimming whitespace', () {
    final controller = ContactSearchController();

    final result = controller.filter(contacts, '  ali ');

    expect(result.map((contact) => contact.name), ['Alice Lee', 'Alicia Keys']);
  });

  test('matches email substrings as well as names', () {
    final controller = ContactSearchController();

    final result = controller.filter(contacts, 'example.org');

    expect(result.map((contact) => contact.name), ['Alicia Keys']);
  });

  test('returns matches sorted by display name without mutating input', () {
    final controller = ContactSearchController();
    final mutableContacts = contacts.toList();

    final result = controller.filter(mutableContacts, 'example');

    expect(result.map((contact) => contact.name), [
      'Alice Lee',
      'Alicia Keys',
      'Bob Stone',
      'Charlie Rivers',
    ]);
    expect(mutableContacts.map((contact) => contact.name), [
      'Charlie Rivers',
      'Alice Lee',
      'Bob Stone',
      'Alicia Keys',
    ]);
  });
}
