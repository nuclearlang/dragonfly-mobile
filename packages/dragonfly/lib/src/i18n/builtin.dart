/// The texts of Dragonfly's own widgets (dialog buttons, form messages). An app dictionary with the same
/// key wins (`assets/i18n/<locale>/dragonfly.json`: `{"dialog": {"accept": "OK"}}`); a locale that is not
/// here uses English.
const Map<String, Map<String, String>> builtinWords = {
  'en': {
    'dragonfly.dialog.accept': 'Accept',
    'dragonfly.dialog.close': 'Close',
    'dragonfly.form.required': 'Required',
    'dragonfly.form.email': 'Invalid email',
    'dragonfly.form.url': 'Invalid URL',
    'dragonfly.form.number': 'Must be a number',
    'dragonfly.form.minLength': 'At least {n} characters',
    'dragonfly.form.maxLength': 'At most {n} characters',
    'dragonfly.form.min': 'Must be at least {n}',
    'dragonfly.form.max': 'Must be at most {n}',
    'dragonfly.form.pattern': 'Invalid format',
    'dragonfly.form.matches': 'Does not match',
  },
  'es': {
    'dragonfly.dialog.accept': 'Aceptar',
    'dragonfly.dialog.close': 'Cerrar',
    'dragonfly.form.required': 'Obligatorio',
    'dragonfly.form.email': 'Email no válido',
    'dragonfly.form.url': 'URL no válida',
    'dragonfly.form.number': 'Debe ser un número',
    'dragonfly.form.minLength': 'Al menos {n} caracteres',
    'dragonfly.form.maxLength': 'Como máximo {n} caracteres',
    'dragonfly.form.min': 'Debe ser al menos {n}',
    'dragonfly.form.max': 'Debe ser como máximo {n}',
    'dragonfly.form.pattern': 'Formato no válido',
    'dragonfly.form.matches': 'No coincide',
  },
};
