void main() {
  try {
    double.parse('a');
  } catch(e) {
    print("double.parse: $e");
  }
  try {
    int.parse('10.5');
  } catch(e) {
    print("int.parse: $e");
  }
  try {
    num.parse('foo');
  } catch(e) {
    print("num.parse: $e");
  }
}
