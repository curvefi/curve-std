# pragma version 0.4.3

"""
@title Admin Groups
@notice Admin group registry with a default admin and per-contract overrides.
@dev Purposes:
    1. Allow setting a custom admin for a specific contract via a group id.
    2. Allow updating the admin address once for a whole group of contracts.
"""

event SetGroupAdmin:
    group_id: indexed(uint256)
    admin: indexed(address)

event SetGroup:
    who: indexed(address)
    group_id: indexed(uint256)

MAX_ADMINS: constant(uint256) = 64
admins: public(DynArray[address, MAX_ADMINS])
admin_group_of: public(HashMap[address, uint256])

@deploy
def __init__(_default_admin: address):
    """
    @notice Initialize with a default admin for group 0.
    @param _default_admin Address for the default admin group.
    """
    assert _default_admin != empty(address)
    id: uint256 = self._add_admin(_default_admin)

@internal
def _add_admin(admin: address) -> uint256:
    """
    @notice Create a new admin group.
    @param admin Address for the new group admin.
    @return group_id The id assigned to the new group.
    """
    assert admin != empty(address)
    id: uint256 = len(self.admins)
    assert id < MAX_ADMINS, "Too many admins"
    self.admins.append(admin)
    log SetGroupAdmin(group_id=id, admin=admin)
    return id

@view
@internal
def _get_admin_of(who: address) -> address:
    """
    @notice Resolve the admin for a contract address.
    @param who Contract address.
    @return admin Address of the resolved admin.
    """
    group_id: uint256 = self.admin_group_of[who]
    assert group_id < len(self.admins), "Unknown group id"
    return self.admins[group_id]

@internal
def _set_group(who: address, group_id: uint256):
    """
    @notice Assign a contract to an admin group.
    @param who Contract address.
    @param group_id Admin group id.
    """
    assert group_id < len(self.admins), "Unknown group id"
    self.admin_group_of[who] = group_id
    log SetGroup(who=who, group_id=group_id)

@internal
def _replace_group_admin(group_id: uint256, new_admin: address):
    """
    @notice Replace the admin address for a group.
    @param group_id Admin group id.
    @param new_admin New admin address.
    """
    assert group_id < len(self.admins), "Unknown group id"
    assert new_admin != empty(address)
    self.admins[group_id] = new_admin
    log SetGroupAdmin(group_id=group_id, admin=new_admin)

@view
@external
def default_admin() -> address:
    """
    @notice Return the default admin address (group 0).
    """
    return self.admins[0]

@view
@external
def admin(_who: address=msg.sender) -> address:
    """
    @notice Return the admin for a contract address.
    @param _who Contract address (defaults to msg.sender).
    """
    return self._get_admin_of(_who)
