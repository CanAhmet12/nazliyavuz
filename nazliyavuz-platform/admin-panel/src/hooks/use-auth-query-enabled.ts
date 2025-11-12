import { authStore } from "@/store/auth-store";

export function useAuthQueryEnabled(): boolean {
  return authStore((state) => Boolean(state.accessToken));
}


