DROP TABLE IF EXISTS `webauthn_credentials`;
CREATE TABLE `webauthn_credentials` (
  `user_id` varchar(255) UNIQUE NOT NULL,
  `credential_id` varchar(255) UNIQUE NOT NULL,
  `display_name` varchar(255) NOT NULL,
  `sign_count` int NOT NULL DEFAULT 0,
  `api_key` varchar(255) DEFAULT NULL,
  `public_key` text
);
DROP TABLE IF EXISTS `passkeys_demo_users`;
CREATE TABLE `passkeys_demo_users` (
  `user_id` varchar(255) UNIQUE NOT NULL,
  `display_name` varchar(255) NOT NULL,
  `credo` text DEFAULT NULL
);
