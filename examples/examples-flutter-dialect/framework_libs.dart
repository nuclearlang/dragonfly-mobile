import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

// Framework libraries (bloc, dio, get_it): their names are imported on their own thanks to the type
// definitions (defs/dart/). emit and state come from BlocBase, the base of Cubit.

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() {
    emit(state + 1);
  }
}

class Api {
  Dio dio = Dio();

  Future<String> load(String url) async {
    final response = await dio.get<String>(url);
    return response.data ?? '';
  }
}

void setup() {
  GetIt.instance.registerSingleton<Api>(Api());
}

class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CounterCubit, int>(builder: (context, count) => Text('$count'));
  }
}
