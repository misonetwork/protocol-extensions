/**************************************************************
 * THIS FILE IS GENERATED AND SHOULD NOT BE MANUALLY MODIFIED *
 **************************************************************/


/**
 * Represents a party's credit on a work or activity. A credit pairs a display name
 * with one or more roles, identifying how a party contributed to the work.
 */

import { type BcsType, bcs } from '@mysten/sui/bcs';
import { MoveStruct } from '../../../utils/index.js';
const $moduleName = 'partyos::credit';
/**
 * A credit attributing roles to a party on a work. Generic over the role type to
 * support domain-specific roles.
 */
export function Credit<Role extends BcsType<any>>(...typeParameters: [
    Role
]) {
    return new MoveStruct({ name: `${$moduleName}::Credit<${typeParameters[0].name as Role['name']}>`, fields: {
            /** Human-readable name to display for this credit. */
            display_name: bcs.string(),
            /** Roles assigned to the credited party. */
            roles: bcs.vector(typeParameters[0])
        } });
}