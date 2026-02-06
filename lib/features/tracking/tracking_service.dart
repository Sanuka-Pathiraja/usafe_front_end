class TrackingService {
  Future<String> getStatus(String parcelId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return 'In Transit';
  }
}
