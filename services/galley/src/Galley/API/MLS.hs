-- This file is part of the Wire Server implementation.
--
-- Copyright (C) 2022 Wire Swiss GmbH <opensource@wire.com>
--
-- This program is free software: you can redistribute it and/or modify it under
-- the terms of the GNU Affero General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option) any
-- later version.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
-- FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
-- details.
--
-- You should have received a copy of the GNU Affero General Public License along
-- with this program. If not, see <https://www.gnu.org/licenses/>.

module Galley.API.MLS
  ( isMLSEnabled,
    assertMLSEnabled,
    postMLSMessage,
    postMLSCommitBundleFromLocalUser,
    postMLSMessageFromLocalUser,
    getMLSPublicKeys,
    formatPublicKeys,
  )
where

import Data.Default
import Galley.API.Error
import Galley.API.MLS.Enabled
import Galley.API.MLS.Message
import Galley.Env
import Imports
import Polysemy
import Polysemy.Error
import Polysemy.Input
import Wire.API.Error
import Wire.API.Error.Galley
import Wire.API.MLS.Keys

getMLSPublicKeys ::
  ( Member (Input Env) r,
    Member (ErrorS 'MLSNotEnabled) r,
    Member (Error InternalError) r
  ) =>
  Maybe MLSPublicKeyFormat ->
  Sem r (MLSKeysByPurpose (MLSKeys SomeKey))
getMLSPublicKeys fmt = do
  publicKeys <- mlsKeysToPublic <$$> getMLSPrivateKeys
  formatPublicKeys fmt publicKeys

formatPublicKeys ::
  (Member (Error InternalError) r) =>
  Maybe MLSPublicKeyFormat ->
  MLSKeysByPurpose MLSPublicKeys ->
  Sem r (MLSKeysByPurpose (MLSKeys SomeKey))
formatPublicKeys fmt publicKeys =
  case fromMaybe def fmt of
    MLSPublicKeyFormatRaw -> pure (fmap (fmap mkSomeKey) publicKeys)
    MLSPublicKeyFormatJWK -> do
      jwks <-
        traverse
          ( note (InternalErrorWithDescription "malformed MLS removal keys")
              . mlsPublicKeysToJWK
          )
          publicKeys
      pure $ fmap (fmap mkSomeKey) jwks
