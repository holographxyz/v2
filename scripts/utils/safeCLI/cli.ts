import 'dotenv/config';

import { Command } from 'commander';
import { prompts } from 'prompts';
import { ethers } from 'ethers';
import 'colors';
import TransportNodeHid from '@ledgerhq/hw-transport-node-hid';
import Eth from '@ledgerhq/hw-app-eth';
import { utils } from 'ethers';

import SafeApiKit from '@safe-global/api-kit';
import Safe, { SigningMethod } from '@safe-global/protocol-kit';
import { MetaTransactionData, OperationType, SafeEIP712Args, SafeSignature } from '@safe-global/safe-core-sdk-types';

const program = new Command();

program.name('ts-utils-cli').version('1.0.0').description('A TypeScript CLI utility');

program
  .command('safeTx')
  .description('Create a Safe transaction')
  .option('--silent', 'Run the command without printing output', false)
  .option('--chain <uint>', 'Specify the chain ID', undefined)
  .option('--to <address>', 'The target contract', undefined)
  .option('--value <uint>', 'The transaction value', '0')
  .option('--calldata <bytes>', 'The transaction calldata', undefined)
  .option('--safe <address>', 'The safe wallet address', undefined)
  .option('--private-key <string>', 'The private key of the Safe signer', undefined)
  .option('--ledger <address>', 'The ledger address of the Safe signer', undefined)
  .option('--rpc <url>', 'The RPC URL', undefined)
  .action(async (options) => {
    // Command arguments
    const chainId = options.chain;
    const calldata = options.calldata;
    const silent = options.silent;
    const safeAddress = options.safe;
    const to = options.to;
    const value = options.value;
    const rpcUrl = options.rpc;
    const privateKey = options.privateKey;
    const ledger = options.ledger;

    const walletAddress = privateKey ? new ethers.Wallet(privateKey).address : ledger;

    if (!chainId) throw new Error('Chain ID is not defined');
    if (!calldata) throw new Error('Calldata is not defined');
    if (!safeAddress) throw new Error('SAFE_ADDRESS is not defined');
    if (!to) throw new Error('Target address is not defined');
    if (!rpcUrl) throw new Error('RPC_URL is not defined');
    if (!privateKey && !ledger) throw new Error('Either private key or ledger address must be defined');
    if (privateKey && ledger) throw new Error('Only one of private key or ledger address must be defined');
    if (privateKey && privateKey.length != 66) throw new Error('Invalid private key length');
    if (ledger && ledger.length != 42) throw new Error('Invalid ledger address length');

    const apiKit = new SafeApiKit({
      chainId: chainId,
    });

    if (!silent) {
      // Log all data and primpt the user if they want to proceed
      console.log('RPC_URL:'.blue, rpcUrl);
      console.log('CHAIN_ID:'.blue, chainId);
      console.log('\n');
      console.log('OWNER_ADDRESS:'.cyan, walletAddress.magenta);
      console.log('SAFE_ADDRESS:'.cyan, safeAddress.magenta);
      console.log('\n');
      console.log('CALLDATA:'.green, calldata.yellow);
      console.log('TARGET_ADDRESS:'.green, to.yellow);
      console.log('VALUE:'.green, value.yellow);
      console.log('\n');


      const proceed = Boolean(
        await prompts.confirm({
          message: 'Do you want to proceed?',
          type: 'toggle',
          name: 'proceed',
        })
      );

      if (proceed != true) {
        console.log('Aborted');
        return;
      }
    }

    const protocolKit = await Safe.init({
      provider: rpcUrl,
      signer: privateKey ? privateKey : undefined,
      safeAddress: safeAddress,
    });

    // Create transaction
    const safeTransactionData: MetaTransactionData = {
      to: to,
      value: value,
      data: calldata,
      operation: OperationType.Call,
    };

    const safeTransaction = await protocolKit.createTransaction({
      transactions: [safeTransactionData],
    });

    const safeTxHash = await protocolKit.getTransactionHash(safeTransaction);

    let signature: SafeSignature;
    if (ledger) {
      try {
        const transport = await TransportNodeHid.create();
        const eth = new Eth(transport);

        // Trouvez le chemin de dérivation correspondant à l'adresse
        const derivationPath = await findDerivationPath(eth, walletAddress);

        if (derivationPath === null) {
          console.error(`Impossible de trouver l'adresse ${walletAddress} dans les chemins de dérivation testés.`);
          await transport.close();
          process.exit(1);
        }

        if (!silent) {
          console.log(
            `Adresse ${
              (await eth.getAddress(derivationPath, false, true)).address
            } trouvée avec le chemin de dérivation : ${derivationPath}`
          );
        }

        // Sign typed data v4 via EIP-712
        const typedData = {
          types: {
            EIP712Domain: [
              { name: 'chainId', type: 'uint256' },
              { name: 'verifyingContract', type: 'address' },
            ],
            SafeTx: [
              { name: 'to', type: 'address' },
              { name: 'value', type: 'uint256' },
              { name: 'data', type: 'bytes' },
              { name: 'operation', type: 'uint8' },
              { name: 'safeTxGas', type: 'uint256' },
              { name: 'baseGas', type: 'uint256' },
              { name: 'gasPrice', type: 'uint256' },
              { name: 'gasToken', type: 'address' },
              { name: 'refundReceiver', type: 'address' },
              { name: 'nonce', type: 'uint256' },
            ],
          },
          domain: {
            chainId: parseInt(chainId),
            verifyingContract: safeAddress,
          },
          primaryType: 'SafeTx',
          message: {
            to: safeTransaction.data.to,
            value: safeTransaction.data.value.toString(),
            data: safeTransaction.data.data,
            operation: safeTransaction.data.operation,
            safeTxGas: safeTransaction.data.safeTxGas.toString(),
            baseGas: safeTransaction.data.baseGas.toString(),
            gasPrice: safeTransaction.data.gasPrice.toString(),
            gasToken: safeTransaction.data.gasToken,
            refundReceiver: safeTransaction.data.refundReceiver,
            nonce: safeTransaction.data.nonce.toString(),
          },
        };

        console.log('Typed data:', typedData);

        // Sign the EIP-712 typed data using the Ledger device
        const sig = await eth.signEIP712Message(derivationPath, typedData);

        let v = typeof sig.v === 'string' ? parseInt(sig.v, 16) : sig.v;
        if (v < 27) v += 27;

        const signatureHex = utils.joinSignature({
          r: '0x' + sig.r,
          s: '0x' + sig.s,
          v: v,
        });

        signature = {
          signer: walletAddress,
          data: signatureHex,
        } as SafeSignature;

        await transport.close();
      } catch (error) {
        console.error('Erreur lors de la signature avec le Ledger:', error);
        process.exit(1);
      }
    } else {
      signature = await protocolKit.signHash(safeTxHash);
    }

    console.log(signature, protocolKit, {
      safeAddress: safeAddress,
      safeTransactionData: safeTransaction.data,
      safeTxHash,
      senderAddress: walletAddress,
      senderSignature: signature.data,
    });

    // Propose transaction to the service
    await apiKit.proposeTransaction({
      safeAddress: safeAddress,
      safeTransactionData: safeTransaction.data,
      safeTxHash,
      senderAddress: walletAddress,
      senderSignature: signature.data,
    });

    console.log('Transaction queued in the Safe wallet'.green);
  });

program.parse(process.argv);

async function findDerivationPath(eth: Eth, targetAddress: string, maxIndex: number = 10): Promise<string | null> {
  const derivationPathTemplates = [
    "44'/60'/{index}'/0/0",
    "44'/60'/0'/0/{index}",
    "44'/60'/0'/{index}",
    "44'/60'/0'/{index}'/0",
  ];

  for (const template of derivationPathTemplates) {
    for (let index = 0; index < maxIndex; index++) {
      const derivationPath = `m/${template.replace('{index}', index.toString())}`;
      const addressInfo = await eth.getAddress(derivationPath, false, true);
      const derivedAddress = addressInfo.address;

      if (derivedAddress.toLowerCase() === targetAddress.toLowerCase()) {
        return derivationPath;
      }
    }
  }
  return null;
}
