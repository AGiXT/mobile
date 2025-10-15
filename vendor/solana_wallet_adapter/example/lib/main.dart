/// Imports
/// ------------------------------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:solana_wallet_adapter/solana_wallet_adapter.dart';
import 'package:solana_web3/programs.dart';
import 'package:solana_web3/solana_web3.dart';


/// Main
/// ------------------------------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: Scaffold(
      body: ExampleApp(),
    ),
  ));
}


/// Transfer Data
/// ------------------------------------------------------------------------------------------------

class TransferData {
  const TransferData({
    required this.transaction,
    required this.receiver,
    required this.lamports,
  });
  final Transaction transaction;
  final Keypair receiver;
  final BigInt lamports;
}


/// Example App
/// ------------------------------------------------------------------------------------------------

class ExampleApp extends StatefulWidget {

  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}


/// Example App State
/// ------------------------------------------------------------------------------------------------

class _ExampleAppState extends State<ExampleApp> {

  /// Initialization future.
  late final Future<void> _future;

  /// NOTE: Your wallet application must be connected to the same cluster.
  static final Cluster cluster = Cluster.devnet;

  /// Request status.
  String? _status;
  
  /// Create an instance of the [SolanaWalletAdapter].
  final SolanaWalletAdapter adapter = SolanaWalletAdapter(
    AppIdentity(
      // uri: Uri.https('merigo.com'),   // YOUR_APP_DOMAIN.
      // icon: Uri.parse('favicon.png'), // YOUR_ICON_PATH relative to `uri`
      // name: 'Example App',            // YOUR_APP_NAME.
    ),
    cluster: cluster,                 // The cluster your wallet is connected to.
    hostAuthority: null,              // The server address that brokers a remote connection.
  );

  /// Load the adapter's stored state.
  @override
  void initState() {
    super.initState();
    _future = SolanaWalletAdapter.initialize();
  }

  /// Connects the application to a wallet running on the device.
  Future<void> _connect() async {
    if (!adapter.isAuthorized) {
      await adapter.authorize(walletUriBase: adapter.store.apps[1].walletUriBase);
      setState(() {});
    }
  }

  /// Disconnects the application from a wallet running on the device.
  Future<void> _disconnect() async {
    if (adapter.isAuthorized) {
      await adapter.deauthorize();
      setState(() {});
    }
  }

  /// Requests an airdrop of 2 SOL for [wallet].
  Future<void> _airdrop(final Connection connection, final Pubkey wallet) async {
    if (cluster != Cluster.mainnet) {
      setState(() => _status = "Requesting airdrop...");
      await connection.requestAndConfirmAirdrop(wallet, solToLamports(2).toInt());
    }
  }

  /// Creates [count] number of SOL transfer transactions.
  Future<List<TransferData>> _createTransfers(
    final Connection connection, {
    required final int count,
  }) async {
  
    // Check connected wallet.
    setState(() => _status = "Pending...");
    final Pubkey? wallet = Pubkey.tryFromBase64(adapter.connectedAccount?.address);
    if (wallet == null) {
      throw 'Wallet not connected';
    }

    // Amount being transfered.
    final BigInt lamports = solToLamports(0.001);

    // Airdrop some SOL to the wallet account if required.
    setState(() => _status = "Checking balance...");
    final int balance = await connection.getBalance(wallet);
    if (balance < (1000000 + lamports.toInt())) _airdrop(connection, wallet);

    // Create a SystemProgram instruction to transfer some SOL.
    setState(() => _status = "Creating transaction...");
    final latestBlockhash = await connection.getLatestBlockhash();
    final List<TransferData> txs = [];
    for (int i = 0; i < count; ++i) {
      final Keypair receiver = Keypair.generateSync();
      final Transaction transaction = Transaction.v0(
        payer: wallet,
        recentBlockhash: latestBlockhash.blockhash,
        instructions: [
          SystemProgram.transfer(
            fromPubkey: wallet, 
            toPubkey: receiver.pubkey, 
            lamports: lamports,
          )
        ]
      );
      txs.add(TransferData(
        transaction: transaction, 
        receiver: receiver,
        lamports: lamports,
      ));
    }
    return txs;
  }

  /// Creates [count] number of large transactions.
  Future<List<Transaction>> _createLargeTransactions(
    final Connection connection, {
    required final int count,
  }) async {
    
    setState(() => _status = "Pending...");
    final Pubkey? wallet = Pubkey.tryFromBase64(adapter.connectedAccount?.address);
    if (wallet == null) {
      throw 'Wallet not connected';
    }

    // Create a SystemProgram instruction to transfer some SOL.
    setState(() => _status = "Creating large transaction...");
    final latestBlockhash = await connection.getLatestBlockhash();
    final List<Transaction> txs = [];
    for (int i = 0; i < count; ++i) {
      final Transaction transaction = Transaction.v0(
        payer: wallet,
        recentBlockhash: latestBlockhash.blockhash,
        instructions: [
          for (int j = 0; j < 2; ++j)
            MemoProgram.create(
              "Abstract. A purely peer-to-peer version of electronic cash would allow online"
              "payments to be sent directly from one party to another without going through a"
              "financial institution. Digital signatures provide part of the solution, but the main"
              "benefits are lost if a trusted third party is still required to prevent double-spending."
              "We propose a solution to the double-spending problem using a peer-to-peer network."
              "The network timestamps transactions by hashing them into an ongoing chain of"
              "hash-based proof-of-work, forming a record that cannot be changed without redoing"
            ),
        ]
      );
      txs.add(transaction);
    }
    return txs;
  }

  /// Checks the results of [transfers].
  Future<void> _confirmTransfers(
    final Connection connection, {
    required final List<String?> signatures,
    required final List<TransferData> transfers, 
  }) async {

      // Wait for confirmations (**You need to convert the base-64 signatures to base-58!**).
      setState(() => _status = "Confirming transaction signature...");
      await Future.wait(
        [for (final sig in signatures) connection.confirmTransaction(base58To64Decode(sig!))], 
        eagerError: true,
      );

      // Get the receiver balances.
      setState(() => _status = "Checking balance...");
      final List<int> receiverBalances = await Future.wait(
        [for (final transfer in transfers) connection.getBalance(transfer.receiver.pubkey)],
        eagerError: true,
      );

      // Check the updated balances.
      final List<String> results = [];
      for (int i = 0; i < receiverBalances.length; ++i) {
        final TransferData transfer = transfers[i];
        final Pubkey pubkey = transfer.receiver.pubkey;
        final BigInt balance = receiverBalances[i].toBigInt();
        if (balance != transfer.lamports) throw Exception('Post transaction balance mismatch.');
        results.add("Transfer: Address $pubkey received $balance SOL");
      }

      // Output the result.
      setState(() => _status = "Success!\n\n"
        "Signatures: $signatures\n\n"
        "${results.join('\n')}"
        "\n"
      );
  }
  
  /// Signs [count] number of transactions (then sends them to the network for processing and 
  /// confirms the transaction results).
  void _signTransactions(final int count) async {
    final String description = "Sign Transactions ($count)";
    try {
      setState(() => _status = "Create $description...");
      final Connection connection = Connection(cluster);
      final List<TransferData> transfers = await _createTransfers(connection, count: count);

      setState(() => _status = "$description...");
      final SignTransactionsResult result = await adapter.signTransactions(
        transfers.map((transfer) => adapter.encodeTransaction(transfer.transaction)).toList(),
      );

      setState(() => _status = "Broadcast $description...");
      final List<String?> signatures = await connection.sendSignedTransactions(
        result.signedPayloads,
        eagerError: true,
      );

      print('SIGN SIGNS ${signatures}');

      setState(() => _status = "Confirm $description...");
      await _confirmTransfers(
        connection, 
        signatures: signatures.map((e) => base58To64Encode(e!)).toList(), 
        transfers: transfers, 
      );

    } catch (error, stack) {
      print('$description Error: $error');
      print('$description Stack: $stack');
      setState(() => _status = error.toString());
    }
  }


  void _signLargeTransactions(final int count) async {
    final String description = "Sign Large Transactions ($count)";
    try {
      setState(() => _status = "Create $description...");
      final Connection connection = Connection(cluster);
      final List<Transaction> transactions = await _createLargeTransactions(connection, count: count);

      setState(() => _status = "$description...");
      final SignTransactionsResult result = await adapter.signTransactions(
        transactions.map((transaction) => adapter.encodeTransaction(transaction)).toList(),
      );

      setState(() => _status = "Broadcast $description...");
      final List<String?> signatures = await connection.sendSignedTransactions(
        result.signedPayloads,
        eagerError: true,
      );

      print('SIGN SIGNS ${signatures}');

      // setState(() => _status = "Confirm $description...");
      // await _confirmTransfers(
      //   connection, 
      //   signatures: signatures.map((e) => base58To64Encode(e!)).toList(), 
      //   transfers: transfers, 
      // );

    } catch (error, stack) {
      print('$description Error: $error');
      print('$description Stack: $stack');
      setState(() => _status = error.toString());
    }
  }

  /// Signs and send [count] number of transactions to the network (then confirms the transaction 
  /// results).
  void _signAndSendTransactions(final int count) async {
    final String description = "Sign And Send Transactions ($count)";
    try {
      setState(() => _status = "Create $description...");
      final Connection connection = Connection(cluster);
      final List<TransferData> transfers = await _createTransfers(connection, count: count);

      setState(() => _status = "$description...");
      final SignAndSendTransactionsResult result = await adapter.signAndSendTransactions(
        transfers.map((transfer) => adapter.encodeTransaction(transfer.transaction)).toList(),
      );

      setState(() => _status = "Confirm $description...");
      await _confirmTransfers(
        connection, 
        signatures: result.signatures, 
        transfers: transfers, 
      );

    } catch (error, stack) {
      print('$description Error: $error');
      print('$description Stack: $stack');
      setState(() => _status = error.toString());
    }
  }

  void _signMessages(final int count) async {
    final String description = "Sign Messages ($count)";
    try {
      setState(() => _status = "Create $description...");
      final List<String> messages = List.generate(
        count, 
        (index) => adapter.encodeMessage('Sign message $index')
      );

      setState(() => _status = "$description...");
      final SignMessagesResult result = await adapter.signMessages(
        messages,
        addresses: [adapter.encodeAccount(adapter.connectedAccount!)],
      );

      setState(() => _status = "Signed Messages ${result.signedPayloads.join('\n')}");
      
    } catch (error, stack) {
      print('$description Error: $error');
      print('$description Stack: $stack');
      setState(() => _status = error.toString());
    }
  }

  Widget _builder(final BuildContext context, final AsyncSnapshot snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const CircularProgressIndicator();
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(24.0),
      children: [

        // ElevatedButton(
        //   onPressed: _disconnect, 
        //   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        //   child: const Text('Disconnect'),
        // ),
        // ElevatedButton(
        //   onPressed: _connect, 
        //   child: const Text('Connect'),
        // ),
        // ElevatedButton(
        //   onPressed: () => _signTransactions(1), 
        //   child: const Text('Sign Transactions (1)'),
        // ),
        // ElevatedButton(
        //   onPressed: () => _signTransactions(3), 
        //   child: const Text('Sign Transactions (3)'),
        // ),
        // ElevatedButton(
        //   onPressed: () => _signAndSendTransactions(1), 
        //   child: const Text('Sign and Send Transactions (1)'),
        // ),
        // ElevatedButton(
        //   onPressed: () => _signAndSendTransactions(3), 
        //   child: const Text('Sign and Send Transactions (3)'),
        // ),
        // ElevatedButton(
        //   onPressed: () => _signMessages(1), 
        //   child: const Text('Sign Messages (1)'),
        // ),
        // ElevatedButton(
        //   onPressed: () => _signMessages(3), 
        //   child: const Text('Sign Messages (3)'),
        // ),

        // const SizedBox(
        //   height: 48.0,
        // ),

        // Connect / Disconnect
        adapter.isAuthorized
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${adapter.connectedAccount?.toBase58()}',
                  textAlign: TextAlign.center,
                ),
                ElevatedButton(
                  onPressed: _disconnect, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Disconnect'),
                ),
              ],
            )
          : ElevatedButton(
              onPressed: _connect, 
              child: const Text('Connect'),
            ),
        const Divider(),
        // Sign Transactions
        Wrap(
          spacing: 24.0,
          runSpacing: 8.0,
          children: [
            ElevatedButton(
              onPressed: adapter.isAuthorized ? () => _signTransactions(1) : null, 
              child: const Text('Sign Transactions (1)'),
            ),
            ElevatedButton(
              onPressed: adapter.isAuthorized ? () => _signTransactions(3) : null, 
              child: const Text('Sign Transactions (3)'),
            ),
            ElevatedButton(
              onPressed: adapter.isAuthorized ? () => _signLargeTransactions(10) : null, 
              child: const Text('Sign Large Transactions'),
            ),
            ElevatedButton(
              onPressed: adapter.isAuthorized ? () => _signAndSendTransactions(1) : null, 
              child: const Text('Sign and Send Transactions (1)'),
            ),
            ElevatedButton(
              onPressed: adapter.isAuthorized ? () => _signAndSendTransactions(3) : null, 
              child: const Text('Sign and Send Transactions (3)'),
            ),
            ElevatedButton(
              onPressed: adapter.isAuthorized ? () => _signMessages(1) : null, 
              child: const Text('Sign Messages (1)'),
            ),
            ElevatedButton(
              onPressed: adapter.isAuthorized ? () => _signMessages(3) : null, 
              child: const Text('Sign Messages (3)'),
            ),
          ],
        ),
        Text(_status ?? ''),
      ],
    );
  }
  
  @override
  Widget build(final BuildContext context) {
    return Center(
      child: FutureBuilder(
        future: _future,
        builder: _builder,
      ),
    );
  }
}