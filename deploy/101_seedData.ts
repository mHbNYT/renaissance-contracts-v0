import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';
import {ethers} from 'hardhat';
import { parseFixed } from '@ethersproject/bignumber';

/**
 * 
 * SCENARIOS
 * 1. NFT1 => FNFT that is just created
 * 2. NFT2 => FNFT that is undergoing IFO but not started
 * 3. NFT3 => FNFT that is undergoing IFO and has started with a few sales here and there
 * 4. NFT4 => FNFT that is undergoing IFO and is paused with a few sales here and there
 * 5. NFT5 => FNFT that has finished IFO with a few sales here and there
 * 6. NFT6 => FNFT that does not have TWAP but does have averageReserve voted that doesn’t meet quorum
 * 7. NFT7 => FNFT that does not have TWAP but has averageReserve that meets quorum
 * 8. NFT8 => FNFT that does have TWAP and averageReserve that doesn’t meet quorum
 * 9. NFT9 => FNFT that does have TWAP above averageReserve price and averageReserve that meets quorum 
 * 
 */


const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {getNamedAccounts} = hre;
  const {get, deploy} = hre.deployments;
  const {deployer} = await getNamedAccounts();

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
  
  // NFT5
  const nft5CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT5", "NFT5"],
    log: true,
    autoMine: true
  });
  const nft5Collection = await ethers.getContractAt(
    nft5CollectionInfo.abi, 
    nft5CollectionInfo.address
  );

  // NFT6
  const nft6CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT6", "NFT6"],
    log: true,
    autoMine: true
  });
  const nft6Collection = await ethers.getContractAt(
    nft6CollectionInfo.abi, 
    nft6CollectionInfo.address
  );

  // NFT7
  const nft7CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT7", "NFT7"],
    log: true,
    autoMine: true
  });
  const nft7Collection = await ethers.getContractAt(
    nft7CollectionInfo.abi, 
    nft7CollectionInfo.address
  );

  // NFT8
  const nft8CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT8", "NFT8"],
    log: true,
    autoMine: true
  });
  const nft8Collection = await ethers.getContractAt(
    nft8CollectionInfo.abi, 
    nft8CollectionInfo.address
  );

  // NFT9
  const nft9CollectionInfo = await deploy('NameableMockNFT', {
    from: deployer,
    args: ["NFT9", "NFT9"],
    log: true,
    autoMine: true
  });
  const nft9Collection = await ethers.getContractAt(
    nft9CollectionInfo.abi, 
    nft9CollectionInfo.address
  );

  // mint
  await nft1Collection.mint(deployer, 1);
  await nft2Collection.mint(deployer, 2);
  await nft3Collection.mint(deployer, 3);
  await nft4Collection.mint(deployer, 4);
  await nft5Collection.mint(deployer, 5);
  await nft6Collection.mint(deployer, 6);
  await nft7Collection.mint(deployer, 7);
  await nft8Collection.mint(deployer, 8);
  await nft9Collection.mint(deployer, 9);

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
  await nft5Collection.approve(FNFTFactoryInfo.address, 5);
  await nft6Collection.approve(FNFTFactoryInfo.address, 6);
  await nft7Collection.approve(FNFTFactoryInfo.address, 7);
  await nft8Collection.approve(FNFTFactoryInfo.address, 8);
  await nft9Collection.approve(FNFTFactoryInfo.address, 9);


  // NFT1 - scenario is done here
  await FNFTFactory.mint(
    "fNFT1", // name
    "fNFT1",  // symbol
    nft1CollectionInfo.address, // collection address
    1, // tokenId
    100, // supply
    parseFixed('1', 18), // initialPrice === 1e18
    10, // fee (1%)
  );

  // NFT2
  await FNFTFactory.mint(
    "fNFT2", // name
    "fNFT2",  // symbol
    nft2CollectionInfo.address, // collection address
    2, // tokenId
    1_000, // supply
    parseFixed('2', 18), // initialPrice === 2e18
    100, // fee (10%)
  );
  const fNFT2Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft2CollectionInfo.address, 2));
  
  // NFT3
  await FNFTFactory.mint(
    "fNFT3", // name
    "fNFT3",  // symbol
    nft3CollectionInfo.address, // collection address
    3, // tokenId
    1_000_000, // supply
    parseFixed('2', 18), // initialPrice == 2e18
    30, // fee (3%)
  );
  const fNFT3Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft3CollectionInfo.address, 3));

  // NFT4
  await FNFTFactory.mint(
    "fNFT4", // name
    "fNFT4",  // symbol
    nft4CollectionInfo.address, // collection address
    4, // tokenId
    1_000_000_000, // supply
    parseFixed('1', 16), // initialPrice
    5, // fee (.5%)
  );
  const fNFT4Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft4CollectionInfo.address, 4));

  // NFT5
  await FNFTFactory.mint(
    "fNFT5", // name
    "fNFT5",  // symbol
    nft5CollectionInfo.address, // collection address
    5, // tokenId
    100, // supply
    parseFixed('1', 18), // initialPrice === 1e18
    10, // fee (1%)
  );
  const fNFT5Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft5CollectionInfo.address, 5));

  // NFT6
  await FNFTFactory.mint(
    "fNFT6", // name
    "fNFT6",  // symbol
    nft6CollectionInfo.address, // collection address
    6, // tokenId
    1_000, // supply
    parseFixed('2', 18), // initialPrice === 2e18
    100, // fee (10%)
  );
  const fNFT6Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft6CollectionInfo.address, 6));

  // NFT7
  await FNFTFactory.mint(
    "fNFT7", // name
    "fNFT7",  // symbol
    nft7CollectionInfo.address, // collection address
    7, // tokenId
    1_000_000, // supply
    parseFixed('2', 18), // initialPrice == 2e18
    30, // fee (3%)
  );
  const fNFT7Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft7CollectionInfo.address, 7));

  // NFT8
  await FNFTFactory.mint(
    "fNFT8", // name
    "fNFT8",  // symbol
    nft8CollectionInfo.address, // collection address
    8, // tokenId
    1_000_000_000, // supply
    parseFixed('1', 16), // initialPrice
    5, // fee (.5%)
  );
  const fNFT8Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft8CollectionInfo.address, 8));

  // NFT9
  await FNFTFactory.mint(
    "fNFT9", // name
    "fNFT9",  // symbol
    nft9CollectionInfo.address, // collection address
    9, // tokenId
    1_000_000_000, // supply
    parseFixed('1', 16), // initialPrice
    5, // fee (.5%)
  );
  const fNFT9Address = await FNFTFactory.fnfts(await FNFTFactory.getFNFTId(nft9CollectionInfo.address, 9));

  // IFOFactory
  const IFOFactoryInfo = await get('IFOFactory');
  const IFOFactory = await ethers.getContractAt(
    IFOFactoryInfo.abi, 
    IFOFactoryInfo.address
  );



  const fNft2 = await ethers.getContractAt('FNFT', fNFT2Address);
  const fNft3 = await ethers.getContractAt('FNFT', fNFT3Address);
  const fNft4 = await ethers.getContractAt('FNFT', fNFT4Address);
  const fNft5 = await ethers.getContractAt('FNFT', fNFT5Address);
  
  await fNft2.approve(IFOFactoryInfo.address, await fNft2.balanceOf(deployer));
  await fNft3.approve(IFOFactoryInfo.address, await fNft3.balanceOf(deployer));
  await fNft4.approve(IFOFactoryInfo.address, await fNft4.balanceOf(deployer));
  await fNft5.approve(IFOFactoryInfo.address, await fNft5.balanceOf(deployer));



  // NFT2 IFO - NFT2 scenario is done here.
  await IFOFactory.create(
    fNFT2Address, // fNft
    10, // amount for sale
    parseFixed('1', 16), // price
    await fNft2.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );

  // NFT3 IFO
  await IFOFactory.create(
    fNFT3Address, // fNft
    500, // amount for sale
    parseFixed('1', 18), // price
    await fNft3.totalSupply(), // cap
    1_000_000, //dduration
    false // allow whitelisting
  );
  const IFO3Address = await IFOFactory.getIFO(fNFT3Address)

  // NFT4 IFO
  await IFOFactory.create(
    fNFT4Address, // fNft
    1_000, // amount for sale
    parseFixed('1', 16), // price
    await fNft4.totalSupply(), // cap
    1_000_000, //duration
    false // allow whitelisting
  );
  const IFO4Address = await IFOFactory.getIFO(fNFT4Address);

  // NFT5 IFO
  await IFOFactory.create(
    fNFT5Address, // fNft
    100, // amount for sale
    parseFixed('1', 15), // price
    await fNft5.totalSupply(), // cap
    86400, // short duration for purposes of testing
    false // allow whitelisting
  );
  const IFO5Address = await IFOFactory.getIFO(fNFT5Address);


  // start IFOs
  const IFO3 = await ethers.getContractAt('IFO', IFO3Address);
  const IFO4 = await ethers.getContractAt('IFO', IFO4Address);
  const IFO5 = await ethers.getContractAt('IFO', IFO5Address);

  await IFO3.start();
  await IFO4.start();
  await IFO5.start();

  const signers = await ethers.getSigners();

  // SIMULATE RANDOM IFO SALE

  // NFT3 scenario is done after this loop.
  signers.forEach(async signer => { // 20 addresses
    const value = await IFO3.price();
    await IFO3.connect(signer).deposit({value});
  });

  signers.slice(10, 20).forEach(async (signer) => {
    const value = await IFO4.price();
    await IFO4.connect(signer).deposit({value});
  });

  signers.slice(0, 9).forEach(async (signer) => {
    const value = await IFO5.price();
    await IFO5.connect(signer).deposit({value});
  });

  // mine here to allow sales time to finish and also to allow IFO5 duration to complete
  await mineNBlocks(86400);

  // Pause IFO, NFT4 sceanrio ends here
  await IFO4.togglePause();


  // END IFO, NFT5 sceanrio ends here
  await IFO5.end();

  // TODO sceanrio 6,7,8,9
};

async function mineNBlocks(n:number) {
  for (let index = 0; index < n; index++) {
    // console.log(`Mining progress ${index}/${n}...`);
    await ethers.provider.send('evm_mine', []);
  }
}


func.tags = ['seed'];
export default func;