// lib/src/data/auto_catalog.dart

// ==========================
// ПОПУЛЯРНЫЕ МАРКИ
// ==========================

const kAutoBrandsPopular = <String>[
  // РФ
  'LADA (ВАЗ)',
  'ГАЗ',
  'УАЗ',

  // Европа/Япония/Корея/США
  'Toyota',
  'BMW',
  'Mercedes-Benz',
  'Audi',
  'Volkswagen',
  'Skoda',
  'Renault',
  'Peugeot',
  'Opel',
  'Volvo',

  'Lexus',
  'Nissan',
  'Honda',
  'Mazda',
  'Mitsubishi',
  'Subaru',
  'Suzuki',

  'Hyundai',
  'Kia',
  'Chevrolet',
  'Ford',

  // Электро
  'Tesla',

  // Китай
  'Changan',
  'Chery',
  'Exeed',
  'Geely',
  'Haval',
  'Omoda',
  'Tank',
  'BYD',
  'GAC',
  'Hongqi',
  'Li Auto',
  'Zeekr',
  'Jetour',

  // На всякий
  'Другая марка',
];

// ==========================
// ВСЕ МОДЕЛИ ПО МАРКАМ
// ==========================

const kAutoModels = <String, List<String>>{
  // ===== РФ =====
  'LADA (ВАЗ)': [
    'Granta',
    'Vesta',
    'Niva Legend',
    'Niva Travel',
    'Largus',
    'XRAY',
    'Kalina',
    'Priora',
    'Другая модель',
  ],
  'ГАЗ': [
    'Газель',
    'Соболь',
    'Волга',
    'Другая модель',
  ],
  'УАЗ': [
    'Patriot',
    'Hunter',
    'Pickup',
    'Буханка',
    'Другая модель',
  ],

  // ===== TOYOTA =====
  'Toyota': [
    'Camry',
    'Corolla',
    'Land Cruiser',
    'RAV4',
    'Prado',
    'Prius',
    'Highlander',
    'Avalon',
    'Yaris',
    'Другая модель',
  ],

  // ===== BMW =====
  'BMW': [
    '1 Series',
    '3 Series',
    '5 Series',
    '7 Series',
    'X1',
    'X3',
    'X5',
    'X6',
    'X7',
    'Другая модель',
  ],

  // ===== MERCEDES =====
  'Mercedes-Benz': [
    'A-Class',
    'C-Class',
    'E-Class',
    'S-Class',
    'GLA',
    'GLC',
    'GLE',
    'GLS',
    'Другая модель',
  ],

  // ===== AUDI =====
  'Audi': [
    'A3',
    'A4',
    'A6',
    'A8',
    'Q3',
    'Q5',
    'Q7',
    'Q8',
    'Другая модель',
  ],

  // ===== VW =====
  'Volkswagen': [
    'Polo',
    'Golf',
    'Passat',
    'Jetta',
    'Tiguan',
    'Touareg',
    'Другая модель',
  ],

  'Skoda': [
    'Octavia',
    'Rapid',
    'Kodiaq',
    'Karoq',
    'Superb',
    'Другая модель',
  ],

  'Renault': [
    'Logan',
    'Sandero',
    'Duster',
    'Kaptur',
    'Arkana',
    'Другая модель',
  ],

  'Peugeot': [
    '206',
    '207',
    '308',
    '408',
    '3008',
    '5008',
    'Другая модель',
  ],

  'Opel': [
    'Astra',
    'Corsa',
    'Insignia',
    'Zafira',
    'Другая модель',
  ],

  'Volvo': [
    'S60',
    'S90',
    'XC60',
    'XC90',
    'Другая модель',
  ],

  // ===== LEXUS =====
  'Lexus': [
    'RX',
    'NX',
    'LX',
    'ES',
    'GX',
    'IS',
    'Другая модель',
  ],

  'Nissan': [
    'Qashqai',
    'X-Trail',
    'Juke',
    'Teana',
    'Almera',
    'Другая модель',
  ],

  'Honda': [
    'Civic',
    'Accord',
    'CR-V',
    'Pilot',
    'Другая модель',
  ],

  'Mazda': [
    'Mazda 3',
    'Mazda 6',
    'CX-5',
    'CX-9',
    'Другая модель',
  ],

  'Mitsubishi': [
    'Lancer',
    'Outlander',
    'Pajero',
    'ASX',
    'Другая модель',
  ],

  'Subaru': [
    'Forester',
    'Outback',
    'Impreza',
    'XV',
    'Другая модель',
  ],

  'Suzuki': [
    'Swift',
    'Vitara',
    'Grand Vitara',
    'Jimny',
    'Другая модель',
  ],

  'Hyundai': [
    'Solaris',
    'Elantra',
    'Sonata',
    'Tucson',
    'Santa Fe',
    'Creta',
    'Другая модель',
  ],

  'Kia': [
    'Rio',
    'Ceed',
    'Cerato',
    'Sportage',
    'Sorento',
    'K5',
    'Seltos',
    'Другая модель',
  ],

  'Chevrolet': [
    'Cruze',
    'Aveo',
    'Niva',
    'Tahoe',
    'Другая модель',
  ],

  'Ford': [
    'Focus',
    'Mondeo',
    'Kuga',
    'Explorer',
    'Другая модель',
  ],

  // ===== TESLA =====
  'Tesla': [
    'Model S',
    'Model 3',
    'Model X',
    'Model Y',
    'Cybertruck',
    'Другая модель',
  ],

  // ===== Китай =====
  'Changan': ['CS35', 'CS55', 'CS75', 'UNI-T', 'UNI-K', 'Другая модель'],
  'Chery': ['Tiggo 4', 'Tiggo 7', 'Tiggo 8', 'Arrizo 5', 'Другая модель'],
  'Exeed': ['LX', 'TXL', 'VX', 'Другая модель'],
  'Geely': ['Coolray', 'Atlas', 'Monjaro', 'Emgrand', 'Другая модель'],
  'Haval': ['Jolion', 'F7', 'Dargo', 'H6', 'Другая модель'],
  'Omoda': ['C5', 'S5', 'Другая модель'],
  'Tank': ['300', '500', 'Другая модель'],
  'BYD': ['Han', 'Tang', 'Song', 'Dolphin', 'Другая модель'],
  'GAC': ['GS3', 'GS5', 'GS8', 'Другая модель'],
  'Hongqi': ['H5', 'HS5', 'HS7', 'Другая модель'],
  'Li Auto': ['L7', 'L8', 'L9', 'Другая модель'],
  'Zeekr': ['001', 'X', '009', 'Другая модель'],
  'Jetour': ['X70', 'X90', 'Dashing', 'Другая модель'],

  'Другая марка': ['Другая модель'],
};

// ==========================
// ПОКОЛЕНИЯ (ПРИМЕРЫ)
// ==========================
// Если нет — просто будет "Не указывать" (это нормально)

const kAutoGenerations = <String, List<String>>{
  // Toyota
  'Toyota|Camry': ['XV40', 'XV50', 'XV70', 'XV80'],
  'Toyota|Corolla': ['E120', 'E150', 'E170', 'E210'],
  'Toyota|Land Cruiser': ['100', '200', '300'],

  // BMW
  'BMW|3 Series': ['E90', 'F30', 'G20'],
  'BMW|5 Series': ['E60', 'F10', 'G30'],

  // Mercedes
  'Mercedes-Benz|C-Class': ['W204', 'W205', 'W206'],
  'Mercedes-Benz|E-Class': ['W212', 'W213'],

  // Tesla
  'Tesla|Model 3': ['Standard', 'Long Range', 'Performance'],
  'Tesla|Model Y': ['Standard', 'Long Range', 'Performance'],

  // Китай примеры
  'Chery|Tiggo 7': ['Pro', 'Pro Max'],
  'Geely|Coolray': ['1 поколение', 'рестайлинг'],

  // РФ примеры
  'LADA (ВАЗ)|Vesta': ['1 поколение', 'рестайлинг'],
  'LADA (ВАЗ)|Granta': ['1 поколение', 'рестайлинг'],
};
