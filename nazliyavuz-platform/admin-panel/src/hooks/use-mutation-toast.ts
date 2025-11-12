import {
  useMutation,
  type UseMutationOptions,
  type UseMutationResult,
} from "@tanstack/react-query";
import toast from "react-hot-toast";

type MutationFn<TData, TVariables> = (variables: TVariables) => Promise<TData>;

type MutationToastOptions<TData, TError, TVariables> =
  UseMutationOptions<TData, TError, TVariables> & {
    successMessage?: string;
    errorMessage?: string;
  };

export function useMutationToast<TData, TError = unknown, TVariables = void>(
  mutationFn: MutationFn<TData, TVariables>,
  {
    successMessage,
    errorMessage,
    onSuccess,
    onError,
    ...options
  }: MutationToastOptions<TData, TError, TVariables> = {},
): UseMutationResult<TData, TError, TVariables> {
  return useMutation<TData, TError, TVariables>({
    mutationFn,
    ...options,
    onSuccess: (data, variables, context, mutation) => {
      toast.success(successMessage ?? "İşlem başarıyla tamamlandı.");
      onSuccess?.(data, variables, context, mutation);
    },
    onError: (error, variables, context, mutation) => {
      const fallbackMessage =
        errorMessage ??
        (error instanceof Error
          ? error.message
          : typeof error === "string"
            ? error
            : "İşlem sırasında bir hata oluştu.");
      toast.error(fallbackMessage);
      onError?.(error, variables, context, mutation);
    },
  });
}

