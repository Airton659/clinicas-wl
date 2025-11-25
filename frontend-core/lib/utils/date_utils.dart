// lib/utils/date_utils.dart

int? calcularIdade(DateTime? dataNascimento) {
  if (dataNascimento == null) return null;

  final hoje = DateTime.now();
  int idade = hoje.year - dataNascimento.year;

  final mesAtual = hoje.month;
  final mesNascimento = dataNascimento.month;

  if (mesAtual < mesNascimento ||
      (mesAtual == mesNascimento && hoje.day < dataNascimento.day)) {
    idade--;
  }

  return idade;
}

String formatarIdade(DateTime? dataNascimento) {
  final idade = calcularIdade(dataNascimento);
  if (idade == null) return 'Não informado';
  return '$idade anos';
}