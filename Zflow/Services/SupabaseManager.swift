import Foundation
import Supabase
import PostgREST

final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

    private init() {
        // ⚠️ Production'da bu değerleri .xcconfig / environment variable'a taşıyın.
        client = SupabaseClient(
            supabaseURL: URL(string: "https://djembgnyxdjyefjlzsmn.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRqZW1iZ255eGRqeWVmamx6c21uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyNjk2MzgsImV4cCI6MjA4Njg0NTYzOH0.pcCF2853WxOYdc588ifAn_cSLkHOgMd72aJS989hxrE",
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}
