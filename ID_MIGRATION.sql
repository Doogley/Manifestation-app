-- ============================================================================
-- ID_MIGRATION.sql — migrate affirmation IDs from sequential numbers to
-- category-prefixed string IDs (AB001, LV001, ...).
--
-- RUN THIS BEFORE DEPLOYING THE NEW index.html. The new client code reads/writes
-- the columns this script creates (user_affirmations.day_number,
-- saved_affirmations.affirmation_id) and upserts on (user_id, day_number).
--
-- Background: in the old schema, user_affirmations.affirmation_id held the DAY
-- NUMBER of the unlock (1, 2, 3, ...), which doubled as the library ID because
-- library IDs were sequential. This migration:
--   1. preserves the day semantics in a new day_number column,
--   2. converts affirmation_id to the new string ID via the mapping below,
--   3. adds saved_affirmations.affirmation_id (string), derived from affirmation_day.
-- The affirmation_text / affirmation_cat columns are untouched and remain the
-- display source of truth, so users' history renders identically either way.
-- ============================================================================

BEGIN;

-- ── Old numeric ID → new string ID mapping (all 530 affirmations) ──────────
CREATE TEMP TABLE _aff_id_map (old_id integer PRIMARY KEY, new_id text NOT NULL) ON COMMIT DROP;
INSERT INTO _aff_id_map (old_id, new_id) VALUES
(1,'AB001'),(2,'AB002'),(3,'AB003'),(4,'AB004'),(5,'AB005'),(6,'AB006'),(7,'AB007'),(8,'AB008'),(9,'AB009'),(10,'AB010'),
(11,'AB011'),(12,'AB012'),(13,'LV001'),(14,'LV002'),(15,'LV003'),(16,'LV004'),(17,'LV005'),(18,'LV006'),(19,'LV007'),(20,'LV008'),
(21,'LV009'),(22,'LV010'),(23,'LV011'),(24,'CO001'),(25,'CO002'),(26,'CO003'),(27,'CO004'),(28,'CO005'),(29,'CO006'),(30,'CO007'),
(31,'CO008'),(32,'CO009'),(33,'CO010'),(34,'CO011'),(35,'CO012'),(36,'HT001'),(37,'HT002'),(38,'HT003'),(39,'HT004'),(40,'HT005'),
(41,'HT006'),(42,'HT007'),(43,'HT008'),(44,'HT009'),(45,'HT010'),(46,'HT011'),(47,'PC001'),(48,'PC002'),(49,'PC003'),(50,'PC004'),
(51,'PC005'),(52,'PC006'),(53,'PC007'),(54,'PC008'),(55,'PC009'),(56,'PC010'),(57,'PC011'),(58,'CR001'),(59,'CR002'),(60,'CR003'),
(61,'CR004'),(62,'CR005'),(63,'CR006'),(64,'CR007'),(65,'CR008'),(66,'CR009'),(67,'CR010'),(68,'CR011'),(69,'HL001'),(70,'HL002'),
(71,'HL003'),(72,'HL004'),(73,'HL005'),(74,'HL006'),(75,'HL007'),(76,'HL008'),(77,'HL009'),(78,'HL010'),(79,'CG001'),(80,'CG002'),
(81,'CG003'),(82,'CG004'),(83,'CG005'),(84,'CG006'),(85,'CG007'),(86,'CG008'),(87,'NB001'),(88,'NB002'),(89,'NB003'),(90,'NB004'),
(91,'NB005'),(92,'NB006'),(93,'NB007'),(94,'FM001'),(95,'FM002'),(96,'FM003'),(97,'FM004'),(98,'FM005'),(99,'GR001'),(100,'GR002'),
(101,'AB013'),(102,'AB014'),(103,'AB015'),(104,'AB016'),(105,'AB017'),(106,'AB018'),(107,'AB019'),(108,'AB020'),(109,'LV012'),(110,'LV013'),
(111,'LV014'),(112,'LV015'),(113,'LV016'),(114,'LV017'),(115,'LV018'),(116,'LV019'),(117,'CO013'),(118,'CO014'),(119,'CO015'),(120,'CO016'),
(121,'CO017'),(122,'CO018'),(123,'CO019'),(124,'CO020'),(125,'HT012'),(126,'HT013'),(127,'HT014'),(128,'HT015'),(129,'HT016'),(130,'HT017'),
(131,'HT018'),(132,'HT019'),(133,'PC012'),(134,'PC013'),(135,'PC014'),(136,'PC015'),(137,'PC016'),(138,'PC017'),(139,'PC018'),(140,'PC019'),
(141,'CR012'),(142,'CR013'),(143,'CR014'),(144,'CR015'),(145,'CR016'),(146,'CR017'),(147,'CR018'),(148,'CR019'),(149,'HL011'),(150,'HL012'),
(151,'HL013'),(152,'HL014'),(153,'HL015'),(154,'HL016'),(155,'HL017'),(156,'HL018'),(157,'CG009'),(158,'CG010'),(159,'CG011'),(160,'CG012'),
(161,'CG013'),(162,'CG014'),(163,'CG015'),(164,'CG016'),(165,'NB008'),(166,'NB009'),(167,'NB010'),(168,'NB011'),(169,'NB012'),(170,'NB013'),
(171,'NB014'),(172,'NB015'),(173,'FM006'),(174,'FM007'),(175,'FM008'),(176,'FM009'),(177,'FM010'),(178,'GR003'),(179,'GR004'),(180,'GR005'),
(181,'GR006'),(182,'GR007'),(183,'GR008'),(184,'GR009'),(185,'GR010'),(186,'GR011'),(187,'GR012'),(188,'GR013'),(189,'GR014'),(190,'GR015'),
(191,'GR016'),(192,'GR017'),(193,'GR018'),(194,'GR019'),(195,'GR020'),(196,'GR021'),(197,'GR022'),(198,'GR023'),(199,'GR024'),(200,'GR025'),
(201,'FM011'),(202,'FM012'),(203,'FM013'),(204,'FM014'),(205,'FM015'),(206,'FM016'),(207,'FM017'),(208,'FM018'),(209,'FM019'),(210,'FM020'),
(211,'FM021'),(212,'FM022'),(213,'FM023'),(214,'FM024'),(215,'FM025'),(216,'FM026'),(217,'FM027'),(218,'FM028'),(219,'FM029'),(220,'FM030'),
(221,'FM031'),(222,'FM032'),(223,'FM033'),(224,'FM034'),(225,'FM035'),(226,'FM036'),(227,'FM037'),(228,'FM038'),(229,'FM039'),(230,'FM040'),
(231,'NB016'),(232,'NB017'),(233,'NB018'),(234,'NB019'),(235,'NB020'),(236,'NB021'),(237,'NB022'),(238,'NB023'),(239,'NB024'),(240,'NB025'),
(241,'NB026'),(242,'NB027'),(243,'NB028'),(244,'NB029'),(245,'NB030'),(246,'NB031'),(247,'NB032'),(248,'NB033'),(249,'NB034'),(250,'NB035'),
(251,'NB036'),(252,'NB037'),(253,'NB038'),(254,'NB039'),(255,'NB040'),(256,'NB041'),(257,'NB042'),(258,'NB043'),(259,'NB044'),(260,'NB045'),
(261,'CG017'),(262,'CG018'),(263,'CG019'),(264,'CG020'),(265,'CG021'),(266,'CG022'),(267,'CG023'),(268,'CG024'),(269,'CG025'),(270,'CG026'),
(271,'CG027'),(272,'CG028'),(273,'CG029'),(274,'CG030'),(275,'CG031'),(276,'CG032'),(277,'CG033'),(278,'CG034'),(279,'CG035'),(280,'CG036'),
(281,'CG037'),(282,'CG038'),(283,'CG039'),(284,'CG040'),(285,'CG041'),(286,'CG042'),(287,'CG043'),(288,'CG044'),(289,'CG045'),(290,'CG046'),
(291,'HL019'),(292,'HL020'),(293,'HL021'),(294,'HL022'),(295,'HL023'),(296,'HL024'),(297,'HL025'),(298,'HL026'),(299,'HL027'),(300,'HL028'),
(301,'HL029'),(302,'HL030'),(303,'HL031'),(304,'HL032'),(305,'HL033'),(306,'HL034'),(307,'HL035'),(308,'HL036'),(309,'HL037'),(310,'HL038'),
(311,'HL039'),(312,'HL040'),(313,'HL041'),(314,'HL042'),(315,'HL043'),(316,'HL044'),(317,'HL045'),(318,'HL046'),(319,'HL047'),(320,'HL048'),
(321,'CR020'),(322,'CR021'),(323,'CR022'),(324,'CR023'),(325,'CR024'),(326,'CR025'),(327,'CR026'),(328,'CR027'),(329,'CR028'),(330,'CR029'),
(331,'CR030'),(332,'CR031'),(333,'CR032'),(334,'CR033'),(335,'CR034'),(336,'CR035'),(337,'CR036'),(338,'CR037'),(339,'CR038'),(340,'CR039'),
(341,'CR040'),(342,'CR041'),(343,'CR042'),(344,'CR043'),(345,'CR044'),(346,'CR045'),(347,'CR046'),(348,'CR047'),(349,'CR048'),(350,'CR049'),
(351,'HT020'),(352,'HT021'),(353,'HT022'),(354,'HT023'),(355,'HT024'),(356,'HT025'),(357,'HT026'),(358,'HT027'),(359,'HT028'),(360,'HT029'),
(361,'HT030'),(362,'HT031'),(363,'HT032'),(364,'HT033'),(365,'HT034'),(366,'HT035'),(367,'HT036'),(368,'HT037'),(369,'HT038'),(370,'HT039'),
(371,'HT040'),(372,'HT041'),(373,'HT042'),(374,'HT043'),(375,'HT044'),(376,'HT045'),(377,'HT046'),(378,'HT047'),(379,'HT048'),(380,'HT049'),
(381,'LV020'),(382,'LV021'),(383,'LV022'),(384,'LV023'),(385,'LV024'),(386,'LV025'),(387,'LV026'),(388,'LV027'),(389,'LV028'),(390,'LV029'),
(391,'LV030'),(392,'LV031'),(393,'LV032'),(394,'LV033'),(395,'LV034'),(396,'LV035'),(397,'LV036'),(398,'LV037'),(399,'LV038'),(400,'LV039'),
(401,'LV040'),(402,'LV041'),(403,'LV042'),(404,'LV043'),(405,'LV044'),(406,'LV045'),(407,'LV046'),(408,'LV047'),(409,'LV048'),(410,'LV049'),
(411,'PC020'),(412,'PC021'),(413,'PC022'),(414,'PC023'),(415,'PC024'),(416,'PC025'),(417,'PC026'),(418,'PC027'),(419,'PC028'),(420,'PC029'),
(421,'PC030'),(422,'PC031'),(423,'PC032'),(424,'PC033'),(425,'PC034'),(426,'PC035'),(427,'PC036'),(428,'PC037'),(429,'PC038'),(430,'PC039'),
(431,'PC040'),(432,'PC041'),(433,'PC042'),(434,'PC043'),(435,'PC044'),(436,'PC045'),(437,'PC046'),(438,'PC047'),(439,'PC048'),(440,'PC049'),
(441,'CO021'),(442,'CO022'),(443,'CO023'),(444,'CO024'),(445,'CO025'),(446,'CO026'),(447,'CO027'),(448,'CO028'),(449,'CO029'),(450,'CO030'),
(451,'CO031'),(452,'CO032'),(453,'CO033'),(454,'CO034'),(455,'CO035'),(456,'CO036'),(457,'CO037'),(458,'CO038'),(459,'CO039'),(460,'CO040'),
(461,'CO041'),(462,'CO042'),(463,'CO043'),(464,'CO044'),(465,'CO045'),(466,'CO046'),(467,'CO047'),(468,'CO048'),(469,'CO049'),(470,'CO050'),
(471,'AB021'),(472,'AB022'),(473,'AB023'),(474,'AB024'),(475,'AB025'),(476,'AB026'),(477,'AB027'),(478,'AB028'),(479,'AB029'),(480,'AB030'),
(481,'AB031'),(482,'AB032'),(483,'AB033'),(484,'AB034'),(485,'AB035'),(486,'AB036'),(487,'AB037'),(488,'AB038'),(489,'AB039'),(490,'AB040'),
(491,'AB041'),(492,'AB042'),(493,'AB043'),(494,'AB044'),(495,'AB045'),(496,'AB046'),(497,'AB047'),(498,'AB048'),(499,'AB049'),(500,'AB050'),
(501,'GR026'),(502,'GR027'),(503,'GR028'),(504,'GR029'),(505,'GR030'),(506,'GR031'),(507,'GR032'),(508,'GR033'),(509,'GR034'),(510,'GR035'),
(511,'GR036'),(512,'GR037'),(513,'GR038'),(514,'GR039'),(515,'GR040'),(516,'GR041'),(517,'GR042'),(518,'GR043'),(519,'GR044'),(520,'GR045'),
(521,'GR046'),(522,'GR047'),(523,'GR048'),(524,'GR049'),(525,'GR050'),(526,'GR051'),(527,'GR052'),(528,'GR053'),(529,'GR054'),(530,'GR055');

-- ── user_affirmations ───────────────────────────────────────────────────────
-- 1) Preserve the day number (old affirmation_id WAS the day number)
ALTER TABLE public.user_affirmations ADD COLUMN IF NOT EXISTS day_number integer;
UPDATE public.user_affirmations SET day_number = affirmation_id::integer WHERE day_number IS NULL;

-- 2) Drop the old unique constraint on (user_id, affirmation_id).
--    String IDs can legitimately repeat per user once a category sequence wraps,
--    so uniqueness moves to (user_id, day_number).
DO $$
DECLARE c record;
BEGIN
  FOR c IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.user_affirmations'::regclass AND contype = 'u'
  LOOP
    EXECUTE format('ALTER TABLE public.user_affirmations DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;

-- 3) Convert affirmation_id to text and remap to the new string IDs
ALTER TABLE public.user_affirmations ALTER COLUMN affirmation_id TYPE text USING affirmation_id::text;
UPDATE public.user_affirmations ua
SET affirmation_id = m.new_id
FROM _aff_id_map m
WHERE ua.affirmation_id = m.old_id::text;

-- 4) New uniqueness + integrity. The client upserts with
--    onConflict: 'user_id,day_number', which requires this constraint.
ALTER TABLE public.user_affirmations ALTER COLUMN day_number SET NOT NULL;
ALTER TABLE public.user_affirmations
  ADD CONSTRAINT user_affirmations_user_id_day_number_key UNIQUE (user_id, day_number);

-- ── saved_affirmations ──────────────────────────────────────────────────────
-- affirmation_day stays the numeric day key the app uses; the new string ID is
-- carried alongside it for content identity.
ALTER TABLE public.saved_affirmations ADD COLUMN IF NOT EXISTS affirmation_id text;
UPDATE public.saved_affirmations sa
SET affirmation_id = m.new_id
FROM _aff_id_map m
WHERE sa.affirmation_day = m.old_id
  AND sa.affirmation_id IS NULL;

COMMIT;

-- ── Post-checks (run manually, should all return 0) ─────────────────────────
-- SELECT count(*) FROM user_affirmations WHERE affirmation_id ~ '^[0-9]+$';
-- SELECT count(*) FROM user_affirmations WHERE day_number IS NULL;
-- SELECT count(*) FROM saved_affirmations WHERE affirmation_id IS NULL;
