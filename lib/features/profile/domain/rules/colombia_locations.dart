import 'package:meta/meta.dart';

/// Departamento de Colombia con su código de WooCommerce (`ipr-frontend` →
/// `src/lib/colombia.ts`).
@immutable
final class ColombiaDepartment {
  const new({required this.code, required this.name});

  final String code;
  final String name;
}

const List<ColombiaDepartment> colombiaDepartments = [
  ColombiaDepartment(code: 'AMZ', name: 'Amazonas'),
  ColombiaDepartment(code: 'ANT', name: 'Antioquia'),
  ColombiaDepartment(code: 'ARU', name: 'Arauca'),
  ColombiaDepartment(code: 'ATL', name: 'Atlántico'),
  ColombiaDepartment(code: 'BOG', name: 'Bogotá'),
  ColombiaDepartment(code: 'BOL', name: 'Bolívar'),
  ColombiaDepartment(code: 'BOY', name: 'Boyacá'),
  ColombiaDepartment(code: 'CAL', name: 'Caldas'),
  ColombiaDepartment(code: 'CAQ', name: 'Caquetá'),
  ColombiaDepartment(code: 'CAS', name: 'Casanare'),
  ColombiaDepartment(code: 'CAU', name: 'Cauca'),
  ColombiaDepartment(code: 'CES', name: 'Cesar'),
  ColombiaDepartment(code: 'CHO', name: 'Chocó'),
  ColombiaDepartment(code: 'COR', name: 'Córdoba'),
  ColombiaDepartment(code: 'CUN', name: 'Cundinamarca'),
  ColombiaDepartment(code: 'GUA', name: 'Guainía'),
  ColombiaDepartment(code: 'GUV', name: 'Guaviare'),
  ColombiaDepartment(code: 'HUI', name: 'Huila'),
  ColombiaDepartment(code: 'GUJ', name: 'La Guajira'),
  ColombiaDepartment(code: 'MAG', name: 'Magdalena'),
  ColombiaDepartment(code: 'MET', name: 'Meta'),
  ColombiaDepartment(code: 'NAR', name: 'Nariño'),
  ColombiaDepartment(code: 'NOR', name: 'Norte de Santander'),
  ColombiaDepartment(code: 'PUT', name: 'Putumayo'),
  ColombiaDepartment(code: 'QUI', name: 'Quindío'),
  ColombiaDepartment(code: 'RIS', name: 'Risaralda'),
  ColombiaDepartment(code: 'SAP', name: 'San Andrés y Providencia'),
  ColombiaDepartment(code: 'SAN', name: 'Santander'),
  ColombiaDepartment(code: 'SUC', name: 'Sucre'),
  ColombiaDepartment(code: 'TOL', name: 'Tolima'),
  ColombiaDepartment(code: 'VAC', name: 'Valle del Cauca'),
  ColombiaDepartment(code: 'VAU', name: 'Vaupés'),
  ColombiaDepartment(code: 'VIC', name: 'Vichada'),
];

const Map<String, String> _packedCities = {
  'AMZ': 'El encanto|La Chorrera|La Pedrera|La Victoria|Leticia|Puerto Alegría|Puerto Arica|Puerto Nariño|Puerto Santander|Tarapacá',
  'ANT': 'Abejorral|Abriaqui|Alejandria|Altamira|Amaga|Amalfi|Andes|Angelopolis|Angostura|Anori|Anza|Apartadó|Arboletes|Argelia|Armenia mantequilla|Barbosa|Bello|Belmira|Betania|Betulia|Bolombolo|Briceño|Buritica|Cáceres|Caicedo|Caldas|Campamento|Cañasgordas|Caracolí|Caramanta|Carepa|Carolina del principe|Caucasia|Chigorodo|Cisneros|Ciudad bolivar|Cocorna|Concepcion|Concordia|Copacabana|Currulao|Dabeiba|Donmatias|Doradal|Ebéjico|El bagre|El carmen de viboral|El doce|El peñol|El santuario|El tigre|El tres|Entrerrios|Envigado|Fredonia|Frontino|Giraldo|Girardota|Gomez plata|Granada|Guadalupe|Guarne|Guatape|Heliconia|Hispania|Itagui|Ituango|Jardin caceres|Jardin suroeste|Jerico|La ceja|La cruzada|La estrella|La pintada|La sierra|La tablaza|La union|Liborina|Llanadas|Llanos de cuivá|Maceo|Marinilla|Medellín|Montebello|Murindo|Mutata|Nariño|Nechi|Necocli|Nueva colonia|Olaya|Palermo|Palmitas|Peque|Pueblorrico|Puerto belgica|Puerto berrio|Puerto nare|Puerto triunfo|Puerto valdivia|Remedios|Retiro|Rionegro|Sabanalarga|Sabaneta|Salgar|San andres de cuerquia|San antonio de prado|San carlos|San francisco|San jeronimo|San jose de la montaña|San jose del nus|San juan de uraba|San luis|San miguel|San pedro de los milagros|San pedro de uraba|San rafael|San roque|San vicente|Santa barbara|Santa elena|Santa fe de antioquia|Santa isabell|Santa rosa de osos|Santiago|Santo domingo|Segovia|Sevilla|Sonson|Sopetran|Tamesis|Taraza|Tarso|Titiribi|Toledo|Turbo|Uramita|Urrao|Valdivia|Valparaiso|Vegachi|Venecia|Versalles|Vigía del fuerte|Yali|Yarumal|Yolombo|Yondo casabe|Zaragoza|Zungo carretera',
  'ARU': 'Arauca|Arauquita|Cravo norte|Fortul|La esmeralda|La pesquera|Puerto nariño|Puerto rondon|Saravena|Tame',
  'ATL': 'Arroyo de piedra|Baranoa|Barranquilla|Campeche|Campo de la cruz|Candelaria|Galapa|Isabel lopez|Juan de acosta|Juan mina|La peña|Luruaco|Malambo|Manati|Molineros|Palmar de varela|Piojo|Playa mendoza|Polonuevo|Ponedera|Puerto colombia|Puerto giraldo|Repelon|Sabanagrande|Sabanalarga|Salgar|Santa lucia|Santa veronica|Santo tomas|Soledad|Suan|Tubara|Usiacuri',
  'BOG': 'Bogotá',
  'BOL': 'Achi|Arenal|Arjona|Ballestas|Barranco de loba|Baru|Bayunca|Buena sena|Calamar|Cantagallo|Cartagena|Cicuco|Clemencia|Cordoba|El carmen de bolivar|El guamo|Galerazamba|Hatillo de loba|Juan arias|La boquilla|Loma de arena|Magangue|Mahates|Margarita|Maria la baja|Mompos|Montecristo|Morales|Norosi|Pasacaballos|Pontezuela|Puerto rico - tiquisio|Regidor|Rio viejo|San estanislao|San fernando|San jacinto|San juan nepomuceno|San martin de loba|San pablo|Santa ana|Santa catalina|Santa rosa|Santa rosa del sur|Simiti|Soplaviento|Talaigua nuevo|Turbaco|Turbana|Villanueva|Zambrano',
  'BOY': 'Almeida|Aquitania|Arcabuco|Belen|Belencito|Berbeo|Beteitiva|Boavita|Boyacá|Briceño|Buenavista|Busbanza|Caldas|Campohermoso|Cerinza|Chinavita|Chiquinquira|Chiquiza|Chiscas|Chita|Chitaraque|Chivata|Chivor|Ciénega|Combita|Coper|Corrales|Coscuez|Covarachia|Cubara|Cucaita|Cuitiva|Duitama|El cocuy|El espino|Firavitoba|Floresta|Gachantiva|Gameza|Garagoa|Guacamayas|Guateque|Guayata|Guicán|Iza|Jenesano|Jericó|La capilla|La uvita|La victoria|Labranzagrande|Macanal|Maripi|Miraflores|Mongua|Mongui|Moniquira|Motavita|Muzo|Nariño|Nobsa|Nuevo colon|Oicata|Otanche|Pachavita|Paez|Paipa|Pajarito|Panqueba|Pantano de vargas|Pauna|Paz de rio|Pesca|Puente boyaca|Puerto boyaca|Puerto serviez|Quipama|Ramiriqui|Raquira|Rondon|Saboya|Sachica|Samaca|San eduardo|San jose de pare|San luis de gaceno|San mateo|San miguel de sema|San pablo de borbur|Santa barbara|Santa maria|Santa rosa de viterbo|Santa sofia|Santana|Sativanorte|Sativasur|Siachoque|Soata|Socha|Socota|Sogamoso|Somondoco|Sora|Soraca|Sotaquirá|Susacon|Sutamarchan|Sutatenza|Tasco|Tenza|Tibana|Tibasosa|Tinjaca|Tipacoque|Toca|Togui|Topaga|Tota|Tunja|Tunungua|Turmeque|Tuta|Tutaza|Umbita|Ventaquemada|Villa de leyva|Viracacha|Zetaquira',
  'CAL': 'Aguadas|Anserma|Aranzazu|Arauca|Arboleda|Arma|Belalcazar|Bolivia|Bonafont|Castilla|Chinchina|Filadelfia|Florencia|Guarinocito|La dorada|La felisa|La merced|Manizales|Manzanares|Marmato|Marquetalia|Marulanda|Montebonito|Neira|Norcasia|Pacora|Palestina|Pensilvania|Riosucio|Risaralda|Salamina|Samana|Samaria|San bartolome|San daniel|San diego|San felix|San jose|Supia|Victoria|Villamaria|Viterbo',
  'CAQ': 'Albania|Belen de los andaquies|Cartagena del chaira|Curillo|El doncello|El paujil|Florencia|La montañita|Morelia|Puerto rico|Rionegro|San jose del fragua|San vicente del caguan|Solita|Valparaiso',
  'CAS': 'Aguaclara|Aguazul|Araguaney|Chámeza|Cusiana pozo|Hato corozal|La chaparrera|La salina|Mani|Monterrey|Nunchia|Orocue|Paz de ariporo|Pore|Recetor|Sabanalarga|Sácama|San luis de palenque|Támara|Tauramena|Trinidad|Villacarola|Villanueva|Yopal',
  'CAU': 'Almaguer|Argelia|Balboa|Bolívar|Buenos Aires|Cajibío|Caldono|Caloto|Corinto|El tambo|Florencia|Guachené|Guapi|Inzá|Jambaló|La Sierra|La Vega|Mercaderes|Miranda|Morales|Padilla|Paez|Patía|Piamonte|Piendamó|Popayán|Puerto Tejada|Puracé|Rosas|San Sebastian|Santa Rosa|Santander de Quilichao|Silvia|Sotara|Suárez|Sucre|Timbío|Timbiquí|Toribio|Totoró|Villa Rica',
  'CES': 'Aguachica|Arjona|Astrea|Ayacucho|Becerril|Bosconia|Caracolicito|Chimichagua|Chiriguana|Codazzi|Curumani|El copey|El paso|Gamarra|Gonzalez|La gloria|La jagua de ibirico|La loma|La paz|Manaure balcon del cesar|Pailitas|Pelaya|Pueblo bello|Rincon hondo|Rio de oro|San alberto|San diego|San martin|San roque|Tamalameque|Valledupar',
  'CHO': 'Acandi|Alto baudo|Andagoya|Animas|Bahia solano mutis|Bajo baudo pizarro|Belen de bajira|Bojaya|Capurgana|Certegui|Condoto|El carmen de atrato|Guarato|Istmina|Jurado|Lloro|Novita|Nuqui|Quibdo|Riosucio|San jose del palmar|Santa maria del darien|Sipi|Tado|Tutunendo|Unguia|Yuto',
  'COR': 'Ayapel|Buena vista|Canalete|Carillo|Cerete|Chima|Chinu|Cienaga de oro|Colomboy|Cotorra|El carito|El varal|El viajano|La apartada|La ye|Lorica|Los cordobas|Momil|Montelibano|Monteria|Moñitos|Planeta rica|Pueblo nuevo|Puerto escondido|Puerto libertador|Purisima|Sahagun|San andres de sotavento|San antero|San bernardo del viento|San carlos|San jose de ure|San pelayo|San sebastian|Tierra alta|Tuchin|Valencia|Villa fatima',
  'CUN': 'Agua de dios|Alban|Anapoima|Anolaima|Apulo|Arbelaez|Bituima|Bojaca|Briceño|Cabrera|Cachipay|Cajicá|Cambao|Caparrapi|Capellania|Caqueza|Carmen de carupa|Cartagena|Chaguani|Chia|Chinauta|Chipaque|Choachi|Choconta|Chusaca|Cogua|Cota|Cucunuba|El charquito|El colegio mesitas|El peñón|El rosal|El sisga|El triunfo|Facatativá|Fomeque|Fosca|Funza|Fuquene|Fusagasuga|Gachala|Gachancipa|Gacheta|Gama|Girardot|Granada|Guacheta|Guaduas|Guasca|Guataqui|Guatavita|Guayabal de siquima|Guayabetal|Gutierrez|Jerusalen|Junin|La calera|La florida|La gran via|La mesa|La palma|La peña|La punta|La union|La vega|La victoria|Lenguazaque|Macheta|Madrid|Manta|Maya|Medina|Mosquera|Nariño|Nemocon|Nilo|Nimaima|Nocaima|Pacho|Paime|Pandi|Paratebueno|Pasca|Puente de piedra|Puente quetame|Puerto bogota|Puerto salgar|Puli|Quebradanegra|Quetame|Quipile|Ricaurte|San ant de tequen|San bernardo|San cayetano|San francisco|San juan de rioseco|Santandersito|Sasaima|Sesquile|Sibate|Silvania|Simijaca|Soacha|Sopo|Subachoque|Subia|Suesca|Supata|Susa|Sutatausa|Tabio|Tausa|Tena|Tenjo|Tibacuy|Tibirita|Tobia|Tocaima|Tocancipa|Topaipi|Tudela|Ubala|Ubaque|Ubate|Une|Utica|Venecia|Vergara|Viani|Villagomez|Villapinzon|Villeta|Viota|Yacopi|Zipacon|Zipaquira',
  'GUA': 'Cacahual|Guaviare|Inirida|Morichal Nuevo|Pana Pana|Puerto Colombia|San Felipe',
  'GUJ': 'Albania|Barrancas|Buenavista|Distraccion|El molino|Fonseca|Hato nuevo|La jagua del pilar|Maicao|Manaure|Mingueo|Riohacha|San juan del cesar|Uribia|Urumita|Villanueva',
  'GUV': 'Calamar|El Retorno|Miraflores|San jose del guaviare',
  'HUI': 'Acevedo|Agrado|Aipe|Algeciras|Altamira|Argentina|Baraya|Belen|Bruselas|Campoalegre|Colombia|Garzon|Gigante|Guadalupe|Hobo|Iquira|La plata|Nataga|Neiva|Oporapa|Paicol|Palermo|Palestina|Pital|Pitalito|Rivera|Salado blanco|San adolfo|San agustin|San jose de isnos|Santa maria|Suaza|Tarqui|Tello|Teruel|Tesalia|Timana|Vegalarga|Villa vieja|Yaguara',
  'MAG': 'Algarrobo|Aracataca|Cerro san antonio|Chivolo|Cienaga|Concordia|El banco|El dificil|El piñon|El reten|Fundacion|Gaira|Guacamayal|Guaimaro|Guamal|La gran via|Media luna|Nueva granada|Orihueca|Palermo|Pedraza|Pijiño del carmen|Pivijay|Plato|Prado sevilla|Pueblonuevo|Puebloviejo|Remolino|Riofrio|Sabanas de san angel|Salamina|San fernando|San sebast de buenavi|San zenon|Santa ana|Santa barbara de pinto|Santa marta|Sitio nuevo|Taganga|Tenerife|Tucurinca',
  'MET': 'Acacias|Apiay|Barranca de upia|Castilla la nueva|Cubarral san luis|Cumaral|Fuente de oro|Granada|Guamal|La macarena|Mesetas|Pachaquiaro|Puerto concordia|Puerto gaitan|Puerto lleras|Puerto lopez|Puerto rico|Restrepo|San juan de arama|San martin|Uribe|Villavicencio|Vista hermosa',
  'NAR': 'Aldana|Altaquer|Ancuya|Barbacoas|Belen|Berruecos arboleda|Buesaco|Buesaquillo|Cabrera|Cajapi|Candelillas|Carlosama  cuaspud|Catambuco|Cebadal|Chachagui|Chucunes|Consaca|Contadero|Cordoba|Cuatro esquinas|Cumbal|Cumbitara|Daza|El charco|El diviso|El encano|El espino|El peñol|El remolino|El rosario|El tablon de gomez|El tambo|Espriella|Funes|Genova|Genoy|Guachavez san cruz|Guachucal|Guaitarilla|Gualmatan|Iles|Imbili|Imues|Ipiales|Jose maria hernandez|Junin|La cruz|La florida|La guayacana|La llanada|La union|Las lajas|Leiva|Linares|Llorente|Mocondino|Nariño|Obonuco|Ospina|Pasto|Piedrahancha|Pilcuan|Pinzon|Policarpa|Potosi|Providencia|Puerres|Pupiales|Ricaurte|Samaniego|San bernardo|San jose de alban|San lorenzo|San pablo|San pedro de cartago|Sandona|Sapuyes|Sotomayor|Taminango|Tangareal carretera|Tangareal del mira|Tangua|Tumaco|Tuquerres|Yacuanquer',
  'NOR': 'Ábrego|Arboledas|Bochalema|Bucarasica|Cáchira|Cácota|Chinácota|Chitagá|Convención|Cúcuta|Cucutilla|Durania|El Carmen|El Zulia|Gramalote|Hacarí|Herrán|La Esperanza|Labateca|Los Patios|Lourdes|Mutiscua|Ocaña|Pamplona|Pamplonita|Puerto Santander|Ragonvalia|Salazar|San Calixto|San Cayetano|Santiago|Sardinata|Silos|Teorama|Tibú|Toledo|Villa Caro|Villa del Rosario',
  'PUT': 'Colon|El tigre|La dorada san miguel|La hormiga - valle guamuez|Mocoa|Orito|Puerto asis|Puerto caicedo|Puerto guzman|Puerto leguizamo|Puerto umbria|San francisco|Santana|Santiago|Sibundoy|Villagarzon',
  'QUI': 'Armenia|Barcelona|Buenavista|Calarca|Circasia|Cordoba|Filandia|Genova|La tebaida|Montenegro|Pijao|Quimbaya|Salento',
  'RIS': 'Apia|Balboa|Belén de Umbria|Dosquebradas|Guática|Irra|La Celia|La Virginia|Marsella|Mistrato|Pereira|Pueblo Rico|Quinchía|San Clemente|Santa Rosa de Cabal|Santuario',
  'SAN': 'Acapulco|Aguada|Aratoca|Barbosa|Barichara|Barrancabermeja|Betulia|Bolivar|Bucaramanga|Capitanejo|Cerrito|Charala|Chipata|Cimitarra|Concepcion|Contratacion|Curiti|El carmen de chucuri|El centro|El peñon|El playon|Enciso|Florian|Floridablanca|Galan|Gambita|Giron|Guaca|Guadalupe|Guavata|Guepsa|Jesus maria|La belleza|La granja|La paz|Landazuri|Lebrija|Los santos|Malaga|Matanza|Mogotes|Molagavita|Oiba|Olival|Onzaga|Paramo|Pescadero|Piedecuesta|Pinchote|Puente nacional|Puerto araujo|Puerto olaya|Puerto parra|Puerto wilches|Rionegro|Sabana de torres|San andres|San benito|San gil|San joaquin|San jose de miranda|San vicente de chucuri|Santa helena del opon|Simacota|Socorro|Suaita|Sucre|Vado real|Valle de san jose|Velez|Villanueva|Zapatoca',
  'SAP': 'Providencia|San andres isla|Santa catalina',
  'SUC': 'Caimito|Corozal|Coveñas|Galeras|Guaranda|La union|Los palmitos|Majagual|Morroa|Ovejas|Sampues|San benito abad|San marcos|San onofre|San pedro|Since|Sincelejo|Sucre|Tolu|Tolu viejo',
  'TOL': 'Alpujarra|Alvarado|Ambalema|Anzoategui|Armero guayabal|Ataco|Boqueron|Buenos aires|Cajamarca|Caldas viejo|Carmen de apicala|Casabianca|Castilla|Chaparral|Chenche asoleado|Chicoral|Coello|Coello - cocora|Convenio|Coyaima|Cunday|Doima|Dolores|El limon|El tablazo|El totumo|Espinal|Falan|Flandes|Fresno|Gaitania|Gualanday|Guamo|Herbeo|Herrera|Honda|Ibague|Icononzo|Junín|Juntas|La arada|La chamba|La palmita|La sierra|Lerida|Libano|Mariquita|Melgar|Murillo|Natagaima|Olaya herrera|Ortega|Padua|Palocabildo|Pastales nuevo|Pastales viejo|Payande|Piedras|Planadas|Playarrica|Prado|Purificacion|Rioblanco|Roncesvalles|Rovira|Saldana|San antonio|San felipe|San luis|Santa isabel|Santa teresa|Santiago perez|Suarez|Tres esquinas|Valle de san juan|Velu|Venadillo|Villa rica|Villahermosa|Villarestrepo',
  'VAC': 'Alcala|Andalucía|Ansermanuevo|Argelia|Bolivar|Buenaventura|Buga|Bugalagrande|Caicedonia|Cali|Calima|Candelaria|Cartago|Dagua|El Águila|El Cairo|El Carmelo|El Cerrito|El Dovio|Florida|Ginebra|Guacarí|Jamundí|La Cumbre|La Paila|La Union|La Victoria|Obando|Palmira|Pradera|Restrepo|Riofrío|Roldanillo|San Pedro|Sevilla|Toro|Trujillo|Tuluá|Ulloa|Versalles|Vijes|Yotoco|Yumbo|Zarzal',
  'VAU': 'Acaricuara|Carurú|Mitu|Papanaua|Taraira|Tío barbas|Yavaraté',
  'VIC': 'Cumaribo|La primavera|Puerto carreño|Santa rosalia',
};

bool isDepartmentCode(String code) => _packedCities.containsKey(code);

String departmentName(String code) {
  for (final d in colombiaDepartments) {
    if (d.code == code) return d.name;
  }
  return code;
}

List<String> citiesOf(String departmentCode) {
  final raw = _packedCities[departmentCode];
  if (raw == null || raw.isEmpty) return const [];
  return raw.split('|');
}
