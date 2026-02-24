# pragma version 0.4.3

"""
@title Contract Groups
@notice Role-aware group registry with per-contract group overrides.
@dev Purposes:
    1. Bind a subject (contract) to a group for a given role id.
    2. Store one assignee value per (role id, group id).
    3. Update a group assignee once and apply it to all bound contracts.
"""

event SetRoleGroupAssignee:
    role_id: indexed(uint256)
    group_id: indexed(uint256)
    assignee: indexed(address)

event SetRoleBinding:
    role_id: indexed(uint256)
    subject: indexed(address)
    group_id: indexed(uint256)

MAX_GROUPS: constant(uint256) = 64

# role_id -> list of accounts by group_id
assignee_by_role_group: public(HashMap[uint256, DynArray[address, MAX_GROUPS]])
# role_id -> subject -> group_id
group_of: public(HashMap[uint256, HashMap[address, uint256]])

@internal
def _init_role(role_id: uint256, assignee: address):
    """
    @notice Create a new role with its default group (group 0).
    @param role_id Role identifier.
    @param assignee Assignee value for default group.
    """
    assert assignee != empty(address)
    assert len(self.assignee_by_role_group[role_id]) == 0, "Role already exists"
    self.assignee_by_role_group[role_id].append(assignee)
    log SetRoleGroupAssignee(role_id=role_id, group_id=0, assignee=assignee)

@internal
def _add_role_group(role_id: uint256, assignee: address) -> uint256:
    """
    @notice Add a new group to an existing role.
    @param role_id Role identifier.
    @param assignee Assignee value for the new group.
    @return group_id The id assigned to the new group.
    """
    assert assignee != empty(address)
    group_id: uint256 = len(self.assignee_by_role_group[role_id])
    assert group_id != 0, "Role is not initialized"
    self.assignee_by_role_group[role_id].append(assignee)
    log SetRoleGroupAssignee(role_id=role_id, group_id=group_id, assignee=assignee)
    return group_id

@view
@internal
def _resolve_assignee_of(role_id: uint256, subject: address) -> address:
    """
    @notice Resolve group assignee for a subject and role id.
    @param role_id Role identifier.
    @param subject Contract address.
    @return assignee Assignee value of the resolved group.
    """
    group_id: uint256 = self.group_of[role_id][subject]
    assert group_id < len(self.assignee_by_role_group[role_id]), "Unknown group id"
    return self.assignee_by_role_group[role_id][group_id]

@internal
def _bind_subject_to_group(role_id: uint256, subject: address, group_id: uint256):
    """
    @notice Bind a subject to an existing role-specific group.
    @param role_id Role identifier.
    @param subject Contract address.
    @param group_id Group id.
    """
    assert group_id < len(self.assignee_by_role_group[role_id]), "Unknown group id"
    assert subject != empty(address)  # easier explorer interaction
    self.group_of[role_id][subject] = group_id
    log SetRoleBinding(role_id=role_id, subject=subject, group_id=group_id)

@internal
def _set_group_assignee(role_id: uint256, group_id: uint256, new_assignee: address):
    """
    @notice Replace assignee value for a role-specific group.
    @param role_id Role identifier.
    @param group_id Group id.
    @param new_assignee New assignee value.
    """
    assert new_assignee != empty(address)
    self.assignee_by_role_group[role_id][group_id] = new_assignee
    log SetRoleGroupAssignee(role_id=role_id, group_id=group_id, assignee=new_assignee)

@view
@internal
def _default_assignee(role_id: uint256) -> address:
    """
    @notice Return the default assignee value for role_id (group 0).
    @param role_id Role identifier.
    """
    return self.assignee_by_role_group[role_id][0]

@view
@external
def resolve_assignee(role_id: uint256, _subject: address=msg.sender) -> address:
    """
    @notice Return assignee value for role_id and subject.
    @param role_id Role identifier.
    @param _subject Contract address (defaults to msg.sender).
    """
    return self._resolve_assignee_of(role_id, _subject)
