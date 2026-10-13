sealed class RecordSaveOutcome {
  const RecordSaveOutcome();
  const factory RecordSaveOutcome.allSaved() = AllRecordsSaved;
  const factory RecordSaveOutcome.partial({required List<String> failedClientIds}) = PartialRecordsSaved;
  const factory RecordSaveOutcome.failed(String message) = RecordSaveFailed;
}
class AllRecordsSaved extends RecordSaveOutcome { const AllRecordsSaved(); }
class PartialRecordsSaved extends RecordSaveOutcome { final List<String> failedClientIds; const PartialRecordsSaved({required this.failedClientIds}); }
class RecordSaveFailed extends RecordSaveOutcome { final String message; const RecordSaveFailed(this.message); }
