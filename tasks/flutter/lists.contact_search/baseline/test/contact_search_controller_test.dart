import 'package:flutter_test/flutter_test.dart';
import 'package:lists_contact_search/contact_search_controller.dart';

void main() {
  const contacts = [
    Contact(name: 'Alice Lee', email: 'alice@example.com'),
    Contact(name: 'Bob Stone', email: 'bob@example.com'),
  ];

  test('blank query returns all contacts', () {
    final controller = ContactSearchController();

    expect(controller.filter(contacts, ''), contacts);
  });

  test('filters by visible name prefix', () {
    final controller = ContactSearchController();

    final result = controller.filter(contacts, 'Alice');

    expect(result.map((contact) => contact.email), ['alice@example.com']);
  });
}
