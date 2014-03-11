-- MySQL dump 10.13  Distrib 5.5.34, for debian-linux-gnu (i686)
--
-- Host: localhost    Database: lenio
-- ------------------------------------------------------
-- Server version	5.5.34-0ubuntu0.12.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Dumping data for table `org`
--

LOCK TABLES `org` WRITE;
/*!40000 ALTER TABLE `org` DISABLE KEYS */;
INSERT INTO `org` VALUES (1,'Bloxham Middle School','2012-01-05'),(2,'St Matthews School','2012-01-05');
/*!40000 ALTER TABLE `org` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `site`
--

LOCK TABLES `site` WRITE;
/*!40000 ALTER TABLE `site` DISABLE KEYS */;
INSERT INTO `site` VALUES (1,'Rugby Site',1),(2,'New Bilton Site',2);
/*!40000 ALTER TABLE `site` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `task`
--

LOCK TABLES `task` WRITE;
/*!40000 ALTER TABLE `task` DISABLE KEYS */;
INSERT INTO `task` VALUES (1,'Heating Boiler Servicing','Annual Inspection required. Cost calculated per boiler unit.','year',1,1),(2,'Fan Convector Heaters','Annual Inspection required. Cost calculated per fan unit.','year',1,1),(3,'Air conditioning units','Annual Inspection required. Check unit operation. Cost calculated per unit.','month',6,1),(4,'Legionella Risk Assessment ','Risk assessment required on a 2 yearly basis or after any works have been carried out to the hot and cold water system.','year',2,1),(5,'Legionella Monthly Testing','Monthly test of the water system is required. This can be undertaken in house by a competent trained person. Flow and return hot water temperatures to be checked, cold water should be at no more than 20 degrees celcius.','month',1,1),(6,'Fire Alarm Regular Test','Weekly test required. This can be undertaken in house by a competent trained person.','week',1,1),(16,'new global task','Desc','day',5,1),(17,'Local item for Bloxham','Desc','week',4,0);
/*!40000 ALTER TABLE `task` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `login`
--

LOCK TABLES `login` WRITE;
/*!40000 ALTER TABLE `login` DISABLE KEYS */;
INSERT INTO `login` VALUES (1,'andy@andybev.com','andy@andybev.com','Andy','Beverley','andrew',0),(2,'mail@andybev.com','mail@andybev.com','Andy','Beverley','andrew',1),(3,'angry@andybev.com','angry@andybev.com','Andy','Beverley','andrew',0),(4,'both@andybev.com','both@andybev.com','Andy','Beverley','andrew',0);
/*!40000 ALTER TABLE `login` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `login_org`
--

LOCK TABLES `login_org` WRITE;
/*!40000 ALTER TABLE `login_org` DISABLE KEYS */;
INSERT INTO `login_org` VALUES (3,1,2),(6,3,1),(8,4,1),(7,4,2);
/*!40000 ALTER TABLE `login_org` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-01-18 11:44:42
