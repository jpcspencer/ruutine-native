import Foundation
import Supabase

extension SupabaseClient {
    static let shared = SupabaseClient(
        supabaseURL: Config.supabaseURL,
        supabaseKey: Config.supabaseAnonKey
    )
}
