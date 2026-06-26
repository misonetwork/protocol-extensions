/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/
import { MoveEnum, MoveStruct, MoveTuple } from '../../../utils/index.js';
import { bcs } from '@mysten/sui/bcs';
const $moduleName = 'ori::walrus_data';
/**
 * Confidentiality of a stored blob: cleartext, or encrypted with an access policy.
 * Only applies to standalone blobs — a quilt patch is a slice of a shared quilt
 * blob and can never be the direct product of an encryption.
 */
export const Confidentiality = new MoveEnum({ name: `${$moduleName}::Confidentiality`, fields: {
        /** The blob is stored in the clear. */
        Unencrypted: null,
        /**
         * The blob is AES-encrypted. `dek` is the AES data-encryption key sealed via Seal
         * — a small ciphertext stored on-chain, not the blob bytes. The sealed DEK is
         * itself a Seal `EncryptedObject`, which already carries the decryption-policy
         * package id, so no separate policy field is stored here. Decryption is gated by
         * that policy package's `seal_approve`, not by this library.
         */
        Encrypted: new MoveStruct({ name: `Confidentiality.Encrypted`, fields: {
                dek: bcs.vector(bcs.u8())
            } })
    } });
/** Represents either a standalone Walrus blob or a patch within a quilt. */
export const WalrusData = new MoveEnum({ name: `${$moduleName}::WalrusData`, fields: {
        /** A standalone Walrus blob. Fields: blob_id, confidentiality. */
        Blob: new MoveTuple({ name: `WalrusData.Blob`, fields: [bcs.u256(), Confidentiality] }),
        /**
         * A patch within a Walrus quilt. Fields: quilt_id, version, start_index,
         * end_index. Always a plaintext reference into a (possibly separately encrypted)
         * quilt blob.
         */
        QuiltPatch: new MoveTuple({ name: `WalrusData.QuiltPatch`, fields: [bcs.u256(), bcs.u8(), bcs.u16(), bcs.u16()] })
    } });