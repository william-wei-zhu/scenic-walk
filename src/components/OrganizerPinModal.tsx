import { useState, useCallback } from 'react';

interface OrganizerPinModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (pin: string) => void;
  error?: string;
}

export const OrganizerPinModal: React.FC<OrganizerPinModalProps> = ({
  isOpen,
  onClose,
  onSubmit,
  error,
}) => {
  const [pin, setPin] = useState('');

  const handleSubmit = useCallback((e: React.FormEvent) => {
    e.preventDefault();
    if (pin.length === 4) {
      onSubmit(pin);
    }
  }, [pin, onSubmit]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-900 rounded-xl shadow-xl p-6 w-full max-w-sm">
        <h2 className="text-xl font-bold text-gray-800 dark:text-gray-100 mb-2">
          Enter Organizer PIN
        </h2>
        <p className="text-gray-600 dark:text-gray-400 text-sm mb-4">
          Enter your 4-digit PIN to start broadcasting your location.
        </p>

        <form onSubmit={handleSubmit}>
          <input
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            maxLength={4}
            value={pin}
            onChange={(e) => setPin(e.target.value.replace(/\D/g, ''))}
            placeholder="0000"
            className="w-full text-center text-3xl tracking-[0.5em] py-3 px-4 border-2 rounded-lg focus:border-green-500 focus:outline-none bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 border-gray-300 dark:border-gray-600"
            autoFocus
          />

          {error && (
            <p className="text-red-500 text-sm mt-2 text-center">{error}</p>
          )}

          <div className="flex gap-3 mt-6">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={pin.length !== 4}
              className="flex-1 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
            >
              Confirm
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default OrganizerPinModal;
