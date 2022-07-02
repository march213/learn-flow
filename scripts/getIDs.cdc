import BottomShot from 0xf8d6e0586b0a20c7

pub fun main(acct: Address): [UInt64] {
  // a reference (&) to the CollectionPublic resource on the BottomShot contracts' Collection
  let publicRef = getAccount(acct).getCapability(/public/BottomShot)
    .borrow<&BottomShot.Collection{BottomShot.CollectionPublic}>()
    ?? panic("Oof ouch owie this account doesn't have a collection there")
  
  return publicRef.getIDs()
}