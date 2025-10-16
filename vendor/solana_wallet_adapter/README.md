Dart implementation of Solana's [Mobile Wallet Adapter Specification](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html) protocol. The protocol exposes functionalities of Android and iOS wallet apps (e.g. [Solflare](https://solflare.com/)) to dapps.

<br>

<img src="https://github.com/merigo-labs/example-apps/blob/master/docs/images/solana_wallet_provider_authorize.gif?raw=true" alt="Authorize App" height="600">
<br>

*Screenshot of [solana_wallet_provider](https://pub.dev/packages/solana_wallet_provider)*

<br>

## Non-privileged Methods
Non-privileged methods do not require the current session to be in an authorized state to invoke them.

- [authorize](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#authorize)
- [deauthorize](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#deauthorize)
- [reauthorize](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#reauthorize)
- [getCapabilities](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#get_capabilities)

<br>

## Privileged Methods
Privileged methods require the current session to be in an authorized state to invoke them. For details on how a session enters and exits an authorized state, see the [non-privileged methods](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#non-privileged-methods).

- [signTransactions](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#sign_transactions)
- [signAndSendTransactions](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#sign_and_send_transactions)
- [signMessages](https://solana-mobile.github.io/mobile-wallet-adapter/spec/spec.html#sign_messages)

<br>

## Setup

Connect your wallet application (e.g. `Phantom`) and `SolanaWalletAdapter` to the same network. *The wallet application may not support localhost.*

<br>

## Example: Authorize

```dart
import 'package:flutter/material.dart';
import 'package:solana_wallet_adapter/solana_wallet_adapter.dart';

void main() {
  runApp(const MaterialApp(
    home: Scaffold(
      body: Center(
        child: AuthorizeButton(),
      ),
    ),
  ));
}

// 1. Create instance of [SolanaWalletAdapter].
final adapter = SolanaWalletAdapter(
  const AppIdentity(),
  // NOTE: CONNECT THE WALLET APPLICATION 
  //       TO THE SAME NETWORK.
  cluster: Cluster.devnet,
);

class AuthorizeButton extends StatefulWidget {
  const AuthorizeButton({super.key});
  @override
  State<AuthorizeButton> createState() => _AuthorizeButtonState();
}

class _AuthorizeButtonState extends State<AuthorizeButton> {
  Object? _output;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () {
            // 2. Authorize application with wallet.
            adapter.authorize()
              .then((result) => setState(() => _output = result.toJson()))
              .catchError((error) => setState(() => _output = error));
          },
          child: const Text('Authorize'),
        ),
        if (_output != null)
          Text(_output.toString()),
      ],
    );
  }
}
```

<br>

## Bugs
Report a bug by opening an [issue](https://github.com/merigo-labs/solana-wallet-adapter/issues/new?template=bug_report.md).

## Feature Requests
Request a feature by raising a [ticket](https://github.com/merigo-labs/solana-wallet-adapter/issues/new?template=feature_request.md).