import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers} from 'hardhat';
import { parseFixed } from '@ethersproject/bignumber';

// deploy demo data
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {getNamedAccounts, artifacts} = hre;
  const {get, deploy} = hre.deployments;
  const {deployer} = await getNamedAccounts();

  // deploy mockNFTs

  // NFT1
  const nft1CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT1", "NFT1"],
    log: true,
    autoMine: true
  });
  const nft1Collection = await ethers.getContractAt(
    nft1CollectionInfo.abi, 
    nft1CollectionInfo.address
  );

  // NFT2
  const nft2CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT2", "NFT2"],
    log: true,
    autoMine: true
  });
  const nft2Collection = await ethers.getContractAt(
    nft2CollectionInfo.abi, 
    nft2CollectionInfo.address
  );

  // NFT3
  const nft3CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT3", "NFT3"],
    log: true,
    autoMine: true
  });
  const nft3Collection = await ethers.getContractAt(
    nft3CollectionInfo.abi, 
    nft3CollectionInfo.address
  );

  // NFT4
  const nft4CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT4", "NFT4"],
    log: true,
    autoMine: true
  });

  const nft4Collection = await ethers.getContractAt(
    nft4CollectionInfo.abi, 
    nft4CollectionInfo.address
  );

  // mint
  nft1Collection.mint(deployer, 1);
  nft2Collection.mint(deployer, 2);
  nft3Collection.mint(deployer, 3);
  nft4Collection.mint(deployer, 4);



  // fractionalize nfts
  const FNFTFactoryInfo = await get("FNFTFactory");
  const FNFTFactory = await ethers.getContractAt(
    FNFTFactoryInfo.abi, 
    FNFTFactoryInfo.address
  );

  // approve factory
  await nft1Collection.approve(FNFTFactoryInfo.address, 1);
  await nft2Collection.approve(FNFTFactoryInfo.address, 2);
  await nft3Collection.approve(FNFTFactoryInfo.address, 3);
  await nft4Collection.approve(FNFTFactoryInfo.address, 4);

  // mint fNfts and store fNft addresses
  await FNFTFactory.mint(
    "fNFT1", // name
    "fNFT1",  // symbol
    nft1CollectionInfo.address, // collection address
    1, // tokenId
    100, // supply
    parseFixed('1', 18), // initialPrice === 1e18
    10, // fee (1%)
  );
  const fNFT1Address = await FNFTFactory.fnfts(await FNFTFactory.getfNFTId(nft1CollectionInfo.address, 1));

  await FNFTFactory.mint(
    "fNFT2", // name
    "fNFT2",  // symbol
    nft2CollectionInfo.address, // collection address
    2, // tokenId
    1_000, // supply
    parseFixed('2', 18), // initialPrice === 2e18
    100, // fee (10%)
  );
  const fNFT2Address = await FNFTFactory.fnfts(await FNFTFactory.getfNFTId(nft2CollectionInfo.address, 2));



  await FNFTFactory.mint(
    "fNFT3", // name
    "fNFT3",  // symbol
    nft3CollectionInfo.address, // collection address
    3, // tokenId
    1_000_000, // supply
    parseFixed('2', 18), // initialPrice == 2e18
    30, // fee (3%)
  );
  const fNFT3Address = await FNFTFactory.fnfts(await FNFTFactory.getfNFTId(nft3CollectionInfo.address, 3));


  await FNFTFactory.mint(
    "fNFT4", // name
    "fNFT4",  // symbol
    nft4CollectionInfo.address, // collection address
    4, // tokenId
    1_000_000_000, // supply
    parseFixed('1', 16), // initialPrice
    5, // fee (.5%)
  );
  const fNFT4Address = await FNFTFactory.fnfts(await FNFTFactory.getfNFTId(nft4CollectionInfo.address, 4));

  const IFOFactoryInfo = await get('IFOFactory');
  const IFOFactory = await ethers.getContractAt(
    IFOFactoryInfo.abi, 
    IFOFactoryInfo.address
  );


  const fNft1 = await ethers.getContractAt('FNFT', fNFT1Address);
  const fNft2 = await ethers.getContractAt('FNFT', fNFT2Address);
  const fNft3 = await ethers.getContractAt('FNFT', fNFT3Address);
  const fNft4 = await ethers.getContractAt('FNFT', fNFT4Address);
  
  await fNft1.approve(IFOFactoryInfo.address, await fNft1.balanceOf(deployer));
  await fNft2.approve(IFOFactoryInfo.address, await fNft2.balanceOf(deployer));
  await fNft3.approve(IFOFactoryInfo.address, await fNft3.balanceOf(deployer));
  await fNft4.approve(IFOFactoryInfo.address, await fNft4.balanceOf(deployer));


  await IFOFactory.create(
    fNFT1Address, // fNft
    10, // amount for sale
    parseFixed('1', 16), // price
    1, // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  await IFOFactory.create(
    fNFT2Address, // fNft
    500, // amount for sale
    parseFixed('1', 18), // price
    100, // cap
    1_000_000, //dduration
    true // allow whitelisting
  )

  await IFOFactory.create(
    fNFT3Address, // fNft
    1_000, // amount for sale
    parseFixed('1', 16), // price
    1, // cap
    1_000_000, //duration
    false // allow whitelisting
  )

  await IFOFactory.create(
    fNFT4Address, // fNft
    1_000_000, // amount for sale
    parseFixed('1', 15), // price
    1_000_000, // cap
    1_000_000, //dduration
    true // allow whitelisting
  )

};
func.tags = ['seed'];
export default func;