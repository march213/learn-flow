import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20

// Here we tell Cadence that our Obstacles contract implements the interface
pub contract Obstacles: NonFungibleToken {
  // This is a simple NFT mint counter
  pub var totalSupply: UInt64

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath

  // Out NFT resource conforms to the INFT interface
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64

    pub let name: String
    pub let description: String
    pub let thumbnail: String

    init(
        id: UInt64,
        name: String,
        description: String,
        thumbnail: String,
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.thumbnail = thumbnail
    }

     pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>()
      ]
    }
    
    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: self.name,
            description: self.description,
            thumbnail: MetadataViews.HTTPFile(
              url: self.thumbnail
            )
          )
      }
      return nil
    }
  }
  
  pub resource interface ObstaclesCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
  }

  pub resource Collection: ObstaclesCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    // the @ indicates that we're working with a resource
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    init() {
      // All resource values MUST be initiated so we make it empty!
      self.ownedNFTs <- {}
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @Obstacles.NFT
      let id: UInt64 = token.id

      // Add the new token to the dictionary, this removes the old one
      let oldToken <- self.ownedNFTs[id] <- token
      
      // Trigger an event to let listeners know an NFT was deposited to this collection
      emit Deposit(id: id, to: self.owner?.address)

      // destroy (burn) the old NFT
      destroy oldToken
    }

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID)
        ?? panic("This collection doesn't contain an NFT with that ID")

      emit Withdraw(id: token.id, from: self.owner?.address)

      return <- token
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let Obstacles = nft as! &Obstacles.NFT
      return Obstacles as &AnyResource{MetadataViews.Resolver}
    }

    // this burns the ENTIRE collection (i.e. every NFT the user owns)
    destroy() {
      destroy self.ownedNFTs
    }
  }

  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  // Mints a new NFT with a new ID and deposits it 
  // in the recipients collection using their collection reference
  pub fun mintNFT(
    recipient: &{NonFungibleToken.CollectionPublic},
    name: String,
    description: String,
    thumbnail: String
  ) {
    // create a new NFT
    var newNFT <- create NFT(
      id: Obstacles.totalSupply,
      name: name,
      description: description,
      thumbnail: thumbnail
    )
    
    // deposit it in the recipient's account using their collection ref
    recipient.deposit(token: <-newNFT)

    Obstacles.totalSupply = Obstacles.totalSupply + UInt64(1)
  }

  init() {
    self.totalSupply = 0
    
    self.CollectionStoragePath = /storage/ObstaclesCollection
    self.CollectionPublicPath = /public/ObstaclesCollection

    // Create a Collection for the deployer
    let collection <- create Collection()
    self.account.save(<-collection, to: self.CollectionStoragePath)

    // Create a public capability for the Collection
    self.account.link<&Obstacles.Collection{NonFungibleToken.CollectionPublic, Obstacles.ObstaclesCollectionPublic, MetadataViews.ResolverCollection}>(
      self.CollectionPublicPath,
      target: self.CollectionStoragePath
    )

    emit ContractInitialized()
  }
}