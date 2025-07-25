DROP TABLE IF EXISTS `webauthn_credentials`;
CREATE TABLE `webauthn_credentials` (
  `id` int(11) NOT NULL,
  `user_id` varchar(255) NOT NULL,
  `credential_id` varbinary(255) NOT NULL,
  `public_key` text NOT NULL
);
