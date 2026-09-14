begin;

-- The source workbook already carries the canonical site UUID. Keep the
-- logistics profile separate from sites so this import cannot alter master data.
with imported_locations (site_id, address_line, latitude, longitude) as (
  values
    ('d0cb9c81-b4d9-4a8a-90b1-6d13b476e6cb'::uuid, 'Calle Guerrero No. 149, Col. Rancho Seco, C.P. 38090, Celaya, Guanajuato', 20.4858333, -100.8016667),
    ('bb325824-38ba-4775-99b3-aaf90b945978'::uuid, 'Av. Poniente 4 No. 118, Ciudad Industrial, C.P. 38010, Celaya, Guanajuato', 20.5513490, -100.8196020),
    ('2d98327c-6b07-4802-b1ad-0199f225b5f2'::uuid, 'Campus Whirlpool, Carretera Federal 45 Km 280 s/n, Predio La Providencia, C.P. 38115, Celaya, Guanajuato', 20.5223400, -100.8657700),
    ('dce8a08e-035e-4a4d-b9fc-df19b19a8e0b'::uuid, 'Carretera Panamericana Km 284, Segunda Fracción de Crespo, C.P. 38110, Celaya, Guanajuato', 20.5141245, -100.8942013),
    ('6c08b37a-dfa1-484f-be80-ad35c2e43edb'::uuid, 'Carretera Cortazar-Estación Km 1.5 s/n, Localidad Santa Anita, C.P. 38300, Cortazar, Guanajuato', 20.4986092, -100.9586447),
    ('7e3861d0-3c1d-44db-940b-03f1de2a5836'::uuid, 'Monroe Tenneco Celaya Planta 2, zona Ciudad Industrial, C.P. 38010, Celaya, Guanajuato', 20.5554900, -100.8165500),
    ('43d797ed-3ec1-4e9e-a0f7-a4f327aea512'::uuid, 'Av. Javier Usabiaga Arroyo No. 102, Bodega 10, Industrial Poniente, C.P. 38160, Apaseo el Grande, Guanajuato', 20.5317729, -100.7348485),
    ('1d927451-5a62-43db-8843-282e493ebfed'::uuid, 'Carretera Panamericana Km 284, 2a Fracción de Crespo, C.P. 38110, Celaya, Guanajuato', 20.5161200, -100.8829490),
    ('ed2972bd-44ee-4ec5-8266-abef691d2b50'::uuid, 'Av. Concepción Béistegui No. 2009, zona Los Cucus / Valle Residencial Los Girasoles, Celaya, Guanajuato', 20.5195610, -100.8566310),
    ('7fab202d-4539-44ed-bb15-b789747db1ce'::uuid, 'Av. Mineral de Valenciana No. 222, Santa Fe I, Guanajuato Puerto Interior, C.P. 36275, Silao, Guanajuato', 21.0131481, -101.4892093),
    ('46e29a9d-1759-43f7-ab9c-73ea590ad372'::uuid, 'Carretera Federal 45 Panamericana Celaya-Salamanca Km 64.8, Poblado de Chinaco, C.P. 38080, zona Celaya/Villagrán, Guanajuato', 20.5185560, -100.9255560),
    ('39b9fac2-eb7f-4bde-a639-82951c0c44df'::uuid, 'Av. El Fortín No. 100, Parque Industrial Amistad Bajío, C.P. 38160, Apaseo el Grande, Guanajuato', 20.5464630, -100.7253260),
    ('b13d137c-e8da-4195-bc23-3de10b679004'::uuid, 'Carretera a San Pedro Mártir No. 246, Colinas de Santa Cruz, C.P. 76113/76117, Santiago de Querétaro, Querétaro', 20.6196759, -100.4540127),
    ('ad5be407-a752-44b5-a13a-00acfabce369'::uuid, 'Av. Guanajuato No. 102, Parque Industrial Amistad Bajío, C.P. 38160, Apaseo el Grande, Guanajuato', 20.5464430, -100.7203150),
    ('4b30ed6f-2fcd-4fe9-b4d3-486f47c482a8'::uuid, 'Av. Guanajuato No. 100, Parque Industrial Amistad Bajío, C.P. 38160, Apaseo el Grande, Guanajuato', 20.5446905, -100.7214792),
    ('81cb693f-48e8-4af8-8263-4f19cd32d2ac'::uuid, 'Calle Ojo De Agua 111, Fraccionamiento El Aguaje, Salvatierra, Guanajuato 38900, México', 20.1993280, -100.8830910),
    ('f3f8f810-42bf-4da4-9456-c130f7dc354a'::uuid, 'Carretera Federal Toluca-Zitácuaro Km 16, San Miguel Almoloyán, C.P. 50906, Almoloya de Juárez, Estado de México', 19.3473078, -99.8029576),
    ('bc2e8a87-b54a-4598-9ff8-cc5769cf7589'::uuid, 'Carretera del Sol (Celaya-Comonfort) s/n, Parque Industrial El Marqués Bajío; referencia del parque: Av. del Sol No. 900, C.P. 38150, Celaya, Guanajuato', 20.4241200, -100.7857400),
    ('1a702b11-51ce-4627-bbc4-8ddde2806119'::uuid, 'Calle Oriente 5 No. 113, Ciudad Industrial, C.P. 38010, Celaya, Guanajuato', 20.5478981, -100.8001647),
    ('e199bb09-5b90-492a-9d14-23e045103d6e'::uuid, 'Parque Industrial Amistad Bajío, Manzana 9, Parcelas 5 a 7, C.P. 38186, Apaseo el Grande, Guanajuato', 20.5437395, -100.7259236),
    ('e48bf759-0c0d-48e6-a4b7-a027c1b0d7b8'::uuid, 'Carretera Federal 45 Libre Km 45+937, Edificio F, Módulos 1-4, Rancho Nuevo, C.P. 38160, Apaseo el Grande, Guanajuato', 20.5261552, -100.7471180),
    ('8b6d6589-43f3-47dd-a309-e5d5c40daafe'::uuid, 'Parqmex Celaya Sur, Av. Amistad, Lotes 1 al 32, Manzana 2, Nave 1A, Parque Industrial Celaya Sur, C.P. 38159, Celaya, Guanajuato', 20.4050317, -100.7962806),
    ('ab8ae593-a9e5-4d45-a7cd-aaa0ebbed493'::uuid, 'Canal de la Venta Km 1.05 s/n, Ex-Hacienda Estrada, C.P. 38115, Celaya, Guanajuato', 20.5363690, -100.8735678),
    ('71f55699-6e35-440e-a16e-973d1b9d097c'::uuid, 'Av. Laurel No. 211, Fracc. Industrial El Vergel, 2a Fracción de Crespo, C.P. 38110, Celaya, Guanajuato', 20.5227056, -100.8909594),
    ('87cb0f0b-4c3b-4eae-bb28-3e92524000ca'::uuid, 'Paseo de los Industriales No. 206, Parque Industrial FIPASI, C.P. 36100, Silao de la Victoria, Guanajuato', 20.8967092, -101.3891985)
)
insert into public.logistics_company_profiles (
  site_id,
  site_name,
  address_line,
  latitude,
  longitude
)
select
  site.id,
  site.name,
  imported.address_line,
  imported.latitude,
  imported.longitude
from imported_locations imported
join public.sites site
  on site.id = imported.site_id
where site.type = 'cliente'
on conflict (site_id) do update
set
  site_name = excluded.site_name,
  address_line = excluded.address_line,
  latitude = excluded.latitude,
  longitude = excluded.longitude;

commit;
